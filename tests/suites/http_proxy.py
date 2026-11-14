import socket
import ssl
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import requests
from websockets.sync.client import connect

from ..utils.config import HTTP_PROXY_PORT
from ..utils.config import HTTPS_SERVER_PORT
from ..utils.config import WEBSOCKET_SERVER_PORT
from ..utils.https_server import HttpsServer
from ..utils.moblin import Moblin
from ..utils.test_case import TestCase
from ..utils.utils import FILES_DIR
from ..utils.websocket_server import WebsocketServer

SMALL_CONTENT = b"Moblin HTTP proxy\n"
LARGE_CONTENT = bytes(range(256)) * 4000
TIMEOUT = 30


def create_static_root() -> Path:
    static_root = FILES_DIR / "http-proxy"
    static_root.mkdir(exist_ok=True)
    (static_root / "small.txt").write_bytes(SMALL_CONTENT)
    (static_root / "large.bin").write_bytes(LARGE_CONTENT)
    return static_root


class HttpProxyTestCase(TestCase):
    def setup(self):
        self.moblin.import_settings(
            overrides={
                "httpProxy": {
                    "enabled": True,
                    "localNetwork": True,
                    "port": HTTP_PROXY_PORT,
                }
            }
        )
        self.moblin.wait_for_tcp_ports(HTTP_PROXY_PORT, ip_address=self.moblin.ip_address)

    def proxy_url(self) -> str:
        return f"http://{self.moblin.ip_address}:{HTTP_PROXY_PORT}"

    def create_session(self, server: HttpsServer) -> requests.Session:
        session = requests.Session()
        session.trust_env = False
        session.proxies = {"https": self.proxy_url()}
        session.verify = str(server.certificate_file)
        return session

    def assert_response(self, response: requests.Response, status_code: int, content: bytes | None = None):
        self.assert_equal(response.status_code, status_code)
        if content is not None:
            self.assert_equal(len(response.content), len(content))
            self.assert_true(response.content == content, "Unexpected content.")

    def assert_client_ip_addresses(self, server: HttpsServer | WebsocketServer):
        device_ip_addresses = {info[4][0] for info in socket.getaddrinfo(self.moblin.ip_address, None)}
        client_ip_addresses = server.client_ip_addresses()
        self.assert_greater(len(client_ip_addresses), 0)
        for client_ip_address in client_ip_addresses:
            self.assert_in(client_ip_address, device_ip_addresses)


class HttpProxyRequests(HttpProxyTestCase):
    """Perform a few HTTPS requests through the HTTP proxy on the device."""

    def run(self):
        static_root = create_static_root()
        host = self.moblin.config.tester_ip_address()
        with HttpsServer(HTTPS_SERVER_PORT, static_root, host) as server:
            with self.create_session(server) as session:
                self.assert_response(
                    session.get(server.url("/small.txt"), timeout=TIMEOUT), 200, SMALL_CONTENT
                )
                self.assert_response(
                    session.get(server.url("/large.bin"), timeout=TIMEOUT), 200, LARGE_CONTENT
                )
                self.assert_response(session.get(server.url("/missing.txt"), timeout=TIMEOUT), 404)
            with self.create_session(server) as session:
                self.assert_response(
                    session.get(server.url("/small.txt"), timeout=TIMEOUT), 200, SMALL_CONTENT
                )
            self.assert_client_ip_addresses(server)


class HttpProxyParallelRequests(HttpProxyTestCase):
    """Perform 1000 HTTPS requests through the HTTP proxy on the device, 50 in parallel."""

    def run(self):
        static_root = create_static_root()
        host = self.moblin.config.tester_ip_address()
        with HttpsServer(HTTPS_SERVER_PORT, static_root, host) as server:
            with ThreadPoolExecutor(max_workers=50) as executor:
                futures = [executor.submit(self.perform_requests, server, 20) for _ in range(50)]
                for future in futures:
                    future.result()
            self.assert_client_ip_addresses(server)

    def perform_requests(self, server: HttpsServer, count: int):
        with self.create_session(server) as session:
            for _ in range(count):
                self.assert_response(
                    session.get(server.url("/small.txt"), timeout=TIMEOUT), 200, SMALL_CONTENT
                )


class HttpProxyWebSocket(HttpProxyTestCase):
    """Send and receive WebSocket messages over TLS through the HTTP proxy on the device."""

    def run(self):
        host = self.moblin.config.tester_ip_address()
        messages: list[str | bytes] = ["Moblin", "HTTP proxy", LARGE_CONTENT]
        with WebsocketServer(WEBSOCKET_SERVER_PORT, host) as server:
            with connect(
                server.url("/echo"),
                ssl=ssl.create_default_context(cafile=str(server.certificate_file)),
                proxy=self.proxy_url(),
                open_timeout=TIMEOUT,
            ) as connection:
                for message in messages:
                    connection.send(message)
                    received = connection.recv(timeout=TIMEOUT)
                    self.assert_equal(len(received), len(message))
                    self.assert_true(received == message, "Unexpected message.")
            self.assert_client_ip_addresses(server)


class HttpProxyErrors(HttpProxyTestCase):
    """Perform requests that the HTTP proxy on the device cannot serve."""

    def run(self):
        self.assert_in("400 Bad Request", self.request("GET http://localhost/ HTTP/1.1\r\n\r\n"))
        self.assert_in("502 Bad Gateway", self.request("CONNECT does-not-exist.invalid:443 HTTP/1.1\r\n\r\n"))

    def request(self, request: str) -> str:
        with socket.create_connection((self.moblin.ip_address, HTTP_PROXY_PORT), timeout=TIMEOUT) as sock:
            sock.sendall(request.encode())
            return sock.recv(1024).decode()


class HttpProxyLocalNetworkDisabled(HttpProxyTestCase):
    """Enable and disable local network access to the HTTP proxy on the device."""

    def run(self):
        self.set_local_network(False)
        time.sleep(3)
        self.assert_false(self.accepts_connections())
        self.set_local_network(True)
        self.wait_until(self.accepts_connections)

    def set_local_network(self, local_network: bool):
        self.moblin.import_settings(
            overrides={
                "httpProxy": {
                    "enabled": True,
                    "localNetwork": local_network,
                    "port": HTTP_PROXY_PORT,
                }
            }
        )

    def accepts_connections(self) -> bool:
        with socket.socket() as sock:
            sock.settimeout(1)
            return sock.connect_ex((self.moblin.ip_address, HTTP_PROXY_PORT)) == 0


def tests(moblin: Moblin):
    return [
        HttpProxyRequests(moblin),
        HttpProxyParallelRequests(moblin),
        HttpProxyWebSocket(moblin),
        HttpProxyErrors(moblin),
        HttpProxyLocalNetworkDisabled(moblin),
    ]
