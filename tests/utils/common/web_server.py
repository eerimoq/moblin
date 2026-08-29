import logging
from pathlib import Path

from systest import ManagedProcess

LOGGER = logging.getLogger(__name__)


class WebServer:
    def __init__(self, port: int, static_root: Path):
        self._server = ManagedProcess(["python", "-m", "http.server", str(port)], LOGGER, cwd=static_root)

    def __enter__(self):
        self._server.start()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self._server.stop()
