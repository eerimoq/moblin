import logging
import os
from collections.abc import Callable
from pathlib import Path

import requests
from systest import ManagedProcess
from systest import wait_until

from .config import MEDIAMTX_API_PORT

LOGGER = logging.getLogger(__name__)
UTILS_DIR = Path(__file__).parent.resolve()
CONFIG_PATH = UTILS_DIR / "mediamtx.yml"


class MediaMtx:
    def __init__(self, log_level: str | None = None, webrtc_host: str | None = None):
        self._log_level = log_level
        self._webrtc_host = webrtc_host
        self._server = ManagedProcess(
            ["mediamtx", str(CONFIG_PATH)],
            LOGGER,
            env=self._create_env(),
            ready=self._wait_until_server_is_ready,
        )

    def __enter__(self):
        self._server.start()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self._server.stop()

    def wait_for_rtmp_stream(self, path, bytes_received):
        self._wait_for_connection(
            "rtmpconns/list",
            "RTMP stream to MediaMTX",
            lambda stream: stream["path"] == path and stream["bytesReceived"] > bytes_received,
        )

    def wait_for_srt_stream(self, path, bytes_received):
        self._wait_for_connection(
            "srtconns/list",
            "SRT stream to MediaMTX",
            lambda stream: stream["path"] == path and stream["bytesReceived"] > bytes_received,
        )

    def wait_for_webrtc_stream(self, path, bytes_received):
        self._wait_for_connection(
            "webrtcsessions/list",
            "WebRTC stream to MediaMTX",
            lambda stream: (
                stream["path"] == path
                and stream["state"] == "publish"
                and stream["bytesReceived"] > bytes_received
            ),
        )

    def wait_for_rtsp_publisher(self, path, bytes_received):
        self._wait_for_connection(
            "rtspsessions/list",
            "RTSP publisher to MediaMTX",
            lambda stream: (
                stream["path"] == path
                and stream["state"] == "publish"
                and stream["inboundBytes"] > bytes_received
            ),
        )

    def wait_for_rtsp_stream(self, path, outbound_bytes):
        self._wait_for_connection(
            "rtspsessions/list",
            "RTSP stream from MediaMTX",
            lambda stream: (
                stream["path"] == path
                and stream["state"] == "read"
                and stream["outboundBytes"] > outbound_bytes
            ),
        )

    def _wait_for_connection(self, endpoint: str, description: str, match: Callable[[dict], bool]):
        wait_until(
            lambda: any(match(stream) for stream in self._api_get(endpoint)["items"]),
            description,
        )

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
        wait_until(lambda: self._api_get("info") is not None, "MediaMTX to start", ignore_errors=True)

    def _api_get(self, path):
        response = requests.get(f"http://localhost:{MEDIAMTX_API_PORT}/v3/{path}", timeout=5)
        response.raise_for_status()
        return response.json()
