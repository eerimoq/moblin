import logging
import os
import subprocess
import time
from pathlib import Path

import requests

from .config import MEDIAMTX_API_PORT
from .utils import log_output

LOGGER = logging.getLogger(__name__)
UTILS_DIR = Path(__file__).parent.resolve()
CONFIG_PATH = UTILS_DIR / "mediamtx.yml"


class MediaMtx:
    def __init__(self, log_level: str | None = None, webrtc_host: str | None = None):
        self._server = None
        self._log_level = log_level
        self._webrtc_host = webrtc_host

    def __enter__(self):
        self._server = subprocess.Popen(
            ["mediamtx", str(CONFIG_PATH)],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            env=self._create_env(),
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
        end_time = time.monotonic() + 30
        while time.monotonic() < end_time:
            response = self._api_get("rtmpconns/list")
            for stream in response["items"]:
                if stream["path"] == path and stream["bytesReceived"] > bytes_received:
                    return
            time.sleep(1)
        raise Exception("Timeout waiting for RTMP stream to MediaMTX")

    def wait_for_srt_stream(self, path, bytes_received):
        end_time = time.monotonic() + 30
        while time.monotonic() < end_time:
            response = self._api_get("srtconns/list")
            for stream in response["items"]:
                if stream["path"] == path and stream["bytesReceived"] > bytes_received:
                    return
            time.sleep(1)
        raise Exception("Timeout waiting for SRT stream to MediaMTX")

    def wait_for_webrtc_stream(self, path, bytes_received):
        end_time = time.monotonic() + 30
        while time.monotonic() < end_time:
            response = self._api_get("webrtcsessions/list")
            for stream in response["items"]:
                if (
                    stream["path"] == path
                    and stream["state"] == "publish"
                    and stream["bytesReceived"] > bytes_received
                ):
                    return
            time.sleep(1)
        raise Exception("Timeout waiting for WebRTC stream to MediaMTX")

    def wait_for_rtsp_publisher(self, path, bytes_received):
        end_time = time.monotonic() + 30
        while time.monotonic() < end_time:
            response = self._api_get("rtspsessions/list")
            for stream in response["items"]:
                if (
                    stream["path"] == path
                    and stream["state"] == "publish"
                    and stream["inboundBytes"] > bytes_received
                ):
                    return
            time.sleep(1)
        raise Exception("Timeout waiting for RTSP publisher to MediaMTX")

    def get_srt_publisher(self, path) -> tuple[str, int] | None:
        for stream in self._api_get("srtconns/list")["items"]:
            if stream["path"] == path and stream["state"] == "publish":
                return stream["id"], stream["bytesReceived"]
        return None

    def wait_for_rtsp_stream(self, outbound_bytes):
        end_time = time.monotonic() + 30
        while time.monotonic() < end_time:
            response = self._api_get("rtspconns/list")
            for stream in response["items"]:
                if stream["outboundBytes"] > outbound_bytes:
                    return
            time.sleep(1)
        raise Exception("Timeout waiting for RTSP stream from MediaMTX")

    def _create_env(self) -> dict[str, str] | None:
        env = {}
        if self._log_level is not None:
            env["MTX_LOGLEVEL"] = self._log_level
        if self._webrtc_host is not None:
            env["MTX_WEBRTCIPSFROMINTERFACES"] = "no"
            env["MTX_WEBRTCADDITIONALHOSTS"] = self._webrtc_host
        if len(env) == 0:
            return None
        return {**os.environ, **env}

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
        response = requests.get(
            f"http://localhost:{MEDIAMTX_API_PORT}/v3/{path}", timeout=5
        )
        response.raise_for_status()
        return response.json()
