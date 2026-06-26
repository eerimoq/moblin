import logging
import subprocess
from .utils import log_output

LOGGER = logging.getLogger(__name__)


class Ffmpeg:
    def __init__(self, url):
        self._url = url
        self._server = None

    def __enter__(self):
        command = [
            "ffmpeg",
            "-re",
            "-i",
            "video.mp4",
            "-c:a",
            "copy",
            "-c:v",
            "libx264",
            "-f",
            "flv",
            self._url,
        ]
        LOGGER.info("Command: %s", " ".join(command))
        self._server = subprocess.Popen(
            command,
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
