import logging
import threading
from collections import Counter
from functools import partial
from http.server import SimpleHTTPRequestHandler
from http.server import ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit

LOGGER = logging.getLogger(__name__)


class RequestHandler(SimpleHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *args):
        LOGGER.debug("%s - %s", self.address_string(), args[0] % args[1:])


class ThreadingServer(ThreadingHTTPServer):
    request_queue_size = 128


class CountingRequestHandler(RequestHandler):
    def __init__(self, *args, on_request, **kwargs):
        self._on_request = on_request
        super().__init__(*args, **kwargs)

    def do_GET(self):
        self._on_request(urlsplit(self.path).path)
        super().do_GET()


class HttpServer:
    def __init__(self, port: int, static_root: Path, host: str):
        self.host = host
        self.port = port
        self._request_paths: list[str] = []
        self._server = ThreadingServer(
            ("0.0.0.0", port),
            partial(
                CountingRequestHandler,
                directory=str(static_root),
                on_request=self._request_paths.append,
            ),
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
        return f"http://{self.host}:{self.port}{path}"

    def request_counts(self) -> dict[str, int]:
        return Counter(self._request_paths)
