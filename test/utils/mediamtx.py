import logging
import os
import subprocess
import time
import requests

LOGGER = logging.getLogger(__name__)
UTILS_DIR = os.path.dirname(os.path.abspath(__file__))


class MediaMtx:
    def __init__(self):
        self._server = None

    def __enter__(self):
        LOGGER.info("Starting")
        config_path = os.path.join(UTILS_DIR, "mediamtx.yml")
        self._server = subprocess.Popen(["mediamtx", config_path])
        try:
            self._wait_until_server_is_ready()
        finally:
            self._server.kill()
        LOGGER.info("Started")
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self._server.kill()

    def _wait_until_server_is_ready(self):
        end_time = time.monotonic() + 15
        while time.monotonic() < end_time:
            try:
                response = requests.get("http://localhost:9997/v3/info", timeout=5)
                response.raise_for_status()
                break
            except Exception:
                time.sleep(0.5)
        else:
            raise Exception("Timeout waiting for MediaMTX to start")
