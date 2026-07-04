import logging
from pathlib import Path
import subprocess

from .utils import log_output

LOGGER = logging.getLogger(__name__)


class WebServer:
    def __init__(self, static_root: Path):
        self._server = None
        self._static_root = static_root

    def __enter__(self):
        self._server = subprocess.Popen(
            ["python", "-m", "http.server", "6967"],
            cwd=self._static_root,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        log_output(self._server.stdout, LOGGER)
        log_output(self._server.stderr, LOGGER)
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        if self._server is not None:
            self._server.kill()
            self._server.wait()
