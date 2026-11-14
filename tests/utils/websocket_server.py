import ssl
import threading

from websockets.sync.server import ServerConnection
from websockets.sync.server import serve

from .https_server import create_self_signed_certificate


class WebsocketServer:
    def __init__(self, port: int, host: str):
        self.host = host
        self.port = port
        self._client_ip_addresses: list[str] = []
        key_file, self.certificate_file = create_self_signed_certificate(host)
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain(self.certificate_file, key_file)
        self._server = serve(self._echo, "0.0.0.0", port, ssl=context)
        self._thread = threading.Thread(target=self._server.serve_forever, daemon=True)

    def __enter__(self):
        self._thread.start()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self._server.shutdown()
        self._thread.join()

    def url(self, path: str) -> str:
        return f"wss://{self.host}:{self.port}{path}"

    def client_ip_addresses(self) -> list[str]:
        return list(self._client_ip_addresses)

    def _echo(self, connection: ServerConnection):
        self._client_ip_addresses.append(connection.remote_address[0])
        for message in connection:
            connection.send(message)
