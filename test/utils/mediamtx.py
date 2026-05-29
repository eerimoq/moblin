import os
import subprocess
import time
import requests

UTILS_DIR = os.path.dirname(os.path.abspath(__file__))


class MediaMtx:
    def __init__(self):
        self._server = None

    def __enter__(self):
        config_path = os.path.join(UTILS_DIR, "mediamtx.yml")
        self._server = subprocess.Popen(["mediamtx", config_path])
        self._wait_until_server_is_ready()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self._server.kill()

    def _wait_until_server_is_ready(self):
        while True:
            try:
                response = requests.get("http://localhost:9997/v3/info")
                response.raise_for_status()
                break
            except Exception:
                time.sleep(0.05)
