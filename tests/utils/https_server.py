import logging
import ssl
import subprocess
import threading
from functools import partial
from ipaddress import ip_address
from pathlib import Path

from .http_server import RequestHandler
from .http_server import ThreadingServer as HttpThreadingServer
from .utils import FILES_DIR

LOGGER = logging.getLogger(__name__)


def create_self_signed_certificate(host: str) -> tuple[Path, Path]:
    try:
        subject_alternative_name = f"IP:{ip_address(host)}"
    except ValueError:
        subject_alternative_name = f"DNS:{host}"
    key_file = FILES_DIR / "https-server-key.pem"
    certificate_file = FILES_DIR / "https-server-certificate.pem"
    subprocess.run(
        [
            "openssl",
            "req",
            "-x509",
            "-newkey",
            "rsa:2048",
            "-sha256",
            "-days",
            "1",
            "-nodes",
            "-subj",
            f"/CN={host}",
            "-addext",
            f"subjectAltName={subject_alternative_name}",
            "-keyout",
            str(key_file),
            "-out",
            str(certificate_file),
        ],
        check=True,
        capture_output=True,
    )
    return key_file, certificate_file


class ThreadingServer(HttpThreadingServer):
    def __init__(self, server_address, handler_class, certificate_file: Path, key_file: Path):
        self._client_ip_addresses: list[str] = []
        super().__init__(server_address, handler_class)
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain(certificate_file, key_file)
        self.socket = context.wrap_socket(self.socket, server_side=True)

    def client_ip_addresses(self) -> list[str]:
        return list(self._client_ip_addresses)

    def process_request(self, request, client_address):
        self._client_ip_addresses.append(client_address[0])
        super().process_request(request, client_address)


class HttpsServer:
    def __init__(self, port: int, static_root: Path, host: str):
        self.host = host
        self.port = port
        key_file, self.certificate_file = create_self_signed_certificate(host)
        self._server = ThreadingServer(
            ("0.0.0.0", port),
            partial(RequestHandler, directory=str(static_root)),
            self.certificate_file,
            key_file,
        )
        self._thread = threading.Thread(target=self._server.serve_forever, daemon=True)

    def __enter__(self):
        self._thread.start()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self._server.shutdown()
        self._thread.join()
        self._server.server_close()

    def url(self, path: str) -> str:
        return f"https://{self.host}:{self.port}{path}"

    def client_ip_addresses(self) -> list[str]:
        return self._server.client_ip_addresses()
