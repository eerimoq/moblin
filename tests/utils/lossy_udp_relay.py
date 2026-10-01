import logging
import random
import select
import socket
import threading
from urllib.parse import urlsplit

LOGGER = logging.getLogger(__name__)


class LossyUdpRelay:
    def __init__(
        self,
        destination: tuple[str, int],
        address: tuple[str, int] = ("127.0.0.1", 0),
        loss_percent: float = 2,
        seed: int = 0,
    ) -> None:
        self.loss_percent = loss_percent
        self._loss_probability = loss_percent / 100
        self._random = random.Random(seed)
        self._client_socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self._client_socket.bind(address)
        self._server_socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self._server_socket.connect(destination)
        self._client_address: tuple[str, int] | None = None
        self._stopped = threading.Event()
        self._thread = threading.Thread(target=self._run, daemon=True)
        self.forwarded = 0
        self.dropped = 0
        self.returned = 0

    @classmethod
    def from_url(cls, url: str, loss_percent: float = 2) -> "LossyUdpRelay":
        parts = urlsplit(url)
        assert parts.hostname is not None and parts.port is not None
        return cls((socket.gethostbyname(parts.hostname), parts.port), loss_percent=loss_percent)

    def relayed_url(self, url: str) -> str:
        host, port = self._client_socket.getsockname()
        return urlsplit(url)._replace(netloc=f"{host}:{port}").geturl()

    def __enter__(self) -> "LossyUdpRelay":
        self._thread.start()
        return self

    def __exit__(self, *_) -> None:
        self._stopped.set()
        self._thread.join()
        self._client_socket.close()
        self._server_socket.close()
        LOGGER.debug(
            "Relay: %d forwarded, %d returned, %d dropped",
            self.forwarded,
            self.returned,
            self.dropped,
        )

    def _run(self) -> None:
        sockets = [self._client_socket, self._server_socket]
        while not self._stopped.is_set():
            readable, _, _ = select.select(sockets, [], [], 0.1)
            for sock in readable:
                if sock is self._client_socket:
                    data, self._client_address = sock.recvfrom(65535)
                    if self._drop():
                        continue
                    try:
                        self._server_socket.send(data)
                    except ConnectionRefusedError:
                        continue
                    self.forwarded += 1
                else:
                    try:
                        data = sock.recv(65535)
                    except ConnectionRefusedError:
                        continue
                    if self._client_address is None or self._drop():
                        continue
                    self._client_socket.sendto(data, self._client_address)
                    self.returned += 1

    def _drop(self) -> bool:
        if self._random.random() < self._loss_probability:
            self.dropped += 1
            return True
        return False
