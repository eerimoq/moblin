import logging
import socket
import sys
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

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._open_requests: set[socket.socket] = set()
        self._open_requests_lock = threading.Lock()

    def process_request(self, request, client_address):
        with self._open_requests_lock:
            self._open_requests.add(request)
        super().process_request(request, client_address)

    def shutdown_request(self, request):
        with self._open_requests_lock:
            self._open_requests.discard(request)
        super().shutdown_request(request)

    def handle_error(self, request, client_address):
        if isinstance(sys.exception(), OSError):
            LOGGER.debug("%s - %s", client_address[0], sys.exception())
        else:
            super().handle_error(request, client_address)

    def shutdown(self):
        super().shutdown()
        with self._open_requests_lock:
            open_requests = list(self._open_requests)
        for request in open_requests:
            try:
                request.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass


class CountingRequestHandler(RequestHandler):
    def __init__(self, *args, on_request, on_post, **kwargs):
        self._on_request = on_request
        self._on_post = on_post
        super().__init__(*args, **kwargs)

    def do_GET(self):
        self._on_request(urlsplit(self.path).path)
        super().do_GET()

    def do_POST(self):
        body = self.rfile.read(int(self.headers.get("Content-Length", "0")))
        self._on_post((urlsplit(self.path).path, body))
        self.send_response(204)
        self.send_header("Content-Length", "0")
        self.end_headers()


class HttpServer:
    def __init__(self, port: int, static_root: Path, host: str):
        self.host = host
        self.port = port
        self._request_paths: list[str] = []
        self._posts: list[tuple[str, bytes]] = []
        self._server = ThreadingServer(
            ("0.0.0.0", port),
            partial(
                CountingRequestHandler,
                directory=str(static_root),
                on_request=self._request_paths.append,
                on_post=self._posts.append,
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

    def posts(self) -> list[tuple[str, bytes]]:
        return list(self._posts)
