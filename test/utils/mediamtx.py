import logging
import os
import subprocess
import time
import requests

from .utils import log_output

LOGGER = logging.getLogger(__name__)
UTILS_DIR = os.path.dirname(os.path.abspath(__file__))


class MediaMtx:
    def __init__(self):
        self._server = None

    def __enter__(self):
        config_path = os.path.join(UTILS_DIR, "mediamtx.yml")
        self._server = subprocess.Popen(
            ["mediamtx", config_path],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        log_output(self._server.stdout, LOGGER)
        log_output(self._server.stderr, LOGGER)
        try:
            self._wait_until_server_is_ready()
        except BaseException:
            self._server.kill()
            self._server.wait()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        if self._server is not None:
            self._server.kill()
            self._server.wait()

    def wait_for_rtmp_stream(self, path, bytes_received):
        end_time = time.monotonic() + 15
        while time.monotonic() < end_time:
            response = self._api_get("rtmpconns/list")
            try:
                for stream in response["items"]:
                    if (
                        stream["path"] == path
                        and stream["bytesReceived"] > bytes_received
                    ):
                        return
            except Exception:
                pass
            time.sleep(1)
        raise Exception("Timeout waiting for RTMP stream to MediaMTX")

    def wait_for_srt_stream(self, path, bytes_received):
        end_time = time.monotonic() + 15
        while time.monotonic() < end_time:
            response = self._api_get("srtconns/list")
            try:
                for stream in response["items"]:
                    if (
                        stream["path"] == path
                        and stream["bytesReceived"] > bytes_received
                    ):
                        return
            except Exception:
                pass
            time.sleep(1)
        raise Exception("Timeout waiting for SRT stream to MediaMTX")

    def _wait_until_server_is_ready(self):
        end_time = time.monotonic() + 15
        while time.monotonic() < end_time:
            try:
                self._api_get("info")
                return
            except Exception:
                time.sleep(0.5)
        raise Exception("Timeout waiting for MediaMTX to start")

    def _api_get(self, path):
        response = requests.get(f"http://localhost:9997/v3/{path}", timeout=5)
        response.raise_for_status()
        return response.json()
