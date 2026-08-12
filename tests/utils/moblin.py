import logging
import re
import socket
import sys
import tempfile
import threading
import time
from base64 import b64encode
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path

import requests
from moblin_assistant import make_client_request

from .arduino import Arduino
from .config import REMOTE_CONTROL_PASSWORD
from .config import RIST_SERVER_PORT
from .config import RTMP_SERVER_PORT
from .config import SRT_SERVER_PORT
from .config import TESTER_RIST_PORT
from .config import TESTER_RTMP_PORT
from .config import TESTER_RTSP_PORT
from .config import TESTER_SRT_PORT
from .config import TESTER_WEBRTC_PORT
from .config import WEB_REMOTE_CONTROL_PORT
from .config import WHIP_SERVER_PORT
from .config import Capability
from .config import Config
from .generate_device_settings import SceneName
from .generate_device_settings import base_settings
from .generate_device_settings import create_settings_file
from .process import ManagedProcess
from .utils import FILES_DIR
from .utils import Range
from .utils import wait_until

LOGGER = logging.getLogger(__name__)
LOGGER_ASSISTANT = logging.getLogger(__name__ + ".assistant")
RE_INGESTS_STATUS = re.compile(r"(\S+) (\S+) \((\S+) (\S+)\) (\S+)")
RE_BITRATE_STATUS = re.compile(r"(\S+) (\S+) ((\S+) )?\((\S+) (\S+)\)")
RE_UPTIME_STATUS = re.compile(r"(\d+)\s*([dhms])")
RE_VIDEO_DECODE_ERROR = re.compile(r"video-decoder: (\S+): Failed to decode frame")
RE_BUFFERED_VIDEO_BUFFERS = re.compile(r"buffered-video: (.+?): (\d+) duplicated and (\d+) dropped buffers")
BITRATE_UNITS = {
    "bps": 1,
    "kbps": 1_000,
    "mbps": 1_000_000,
    "gbps": 1_000_000_000,
}
TOTAL_BYTES_UNITS = {
    "byte": 1,
    "bytes": 1,
    "kb": 1_000,
    "mb": 1_000_000,
    "gb": 1_000_000_000,
    "tb": 1_000_000_000_000,
}
UPTIME_UNITS = {"d": 86400, "h": 3600, "m": 60, "s": 1}


class VideoDecodeErrors:
    def __init__(self):
        self._lock = threading.Lock()
        self._counts: defaultdict[str, int] = defaultdict(int)

    def handle_log_entry(self, entry: str):
        mo = RE_VIDEO_DECODE_ERROR.search(entry)
        if mo is None:
            return
        with self._lock:
            self._counts[mo.group(1)] += 1

    def counts(self) -> dict[str, int]:
        with self._lock:
            return dict(self._counts)


@dataclass
class BufferedVideoBuffersCounts:
    duplicated: dict[str, int]
    dropped: dict[str, int]


class BufferedVideoBuffers:
    def __init__(self):
        self._lock = threading.Lock()
        self._duplicated: defaultdict[str, int] = defaultdict(int)
        self._dropped: defaultdict[str, int] = defaultdict(int)

    def handle_log_entry(self, entry: str):
        mo = RE_BUFFERED_VIDEO_BUFFERS.search(entry)
        if mo is None:
            return
        with self._lock:
            self._duplicated[mo.group(1)] += int(mo.group(2))
            self._dropped[mo.group(1)] += int(mo.group(3))

    def counts(self) -> BufferedVideoBuffersCounts:
        with self._lock:
            return BufferedVideoBuffersCounts(dict(self._duplicated), dict(self._dropped))


class Moblin:
    def __init__(self, config: Config, arduino: Arduino | None, moving_picture: bool):
        self.config = config
        self.arduino = arduino
        self.video_decode_errors = VideoDecodeErrors()
        self.buffered_video_buffers = BufferedVideoBuffers()
        self._device_name = config.device_name()
        self._remote_control_port = config.remote_control_port()
        self._server = ManagedProcess(
            [
                sys.executable,
                "-u",
                "-m",
                "moblin_assistant",
                "--port",
                str(self._remote_control_port),
                "run",
                "--password",
                REMOTE_CONTROL_PASSWORD,
            ],
            LOGGER_ASSISTANT,
            observer=self._handle_log_entry,
            ready=self._wait_until_streamer_is_connected,
        )
        self.ip_address = config.moblin_ip_address()
        self._tester_ip_address = config.tester_ip_address()
        self._tester_media_ip_address = self._tester_ip_address
        self._device_media_ip_address = self.ip_address
        self._capabilities = config.capabilities()
        self._moving_picture = moving_picture
        self._chat_message_id = 0

    def __enter__(self):
        self._server.start()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self._server.stop()

    def _handle_log_entry(self, entry: str):
        self.video_decode_errors.handle_log_entry(entry)
        self.buffered_video_buffers.handle_log_entry(entry)

    def import_settings(self, overrides, files: dict[str, Path] | None = None):
        settings = base_settings(self.config)
        settings.update(overrides)
        with tempfile.TemporaryDirectory() as settings_dir:
            settings_file = Path(settings_dir) / "settings.zip"
            create_settings_file(settings, settings_file, files)
            try:
                self._request(
                    {"importSettings": {"data": b64encode(settings_file.read_bytes()).decode("utf-8")}}
                )
            except Exception:
                pass
            time.sleep(2)

    def set_scene(self, name: SceneName):
        self._request({"setScene": {"id": self._get_settings_id("scenes", name)}})

    def set_talkback_mic(self, name):
        self._request({"setTalkbackMic": {"id": self._get_settings_id("mics", name)}})

    def set_muted(self, on: bool):
        self._request({"setMute": {"on": on}})

    def send_chat_message(self, text: str, is_moderator: bool = True):
        self._request(
            {
                "chatMessages": {
                    "history": False,
                    "messages": [self._create_chat_message(text, is_moderator)],
                }
            }
        )

    def go_live(self):
        self._request({"setLive": {"on": True}})

    def end(self):
        self._request({"setLive": {"on": False}})

    def start_recording(self):
        self._request({"setRecord": {"on": True}})

    def stop_recording(self):
        self._request({"setRecord": {"on": False}})

    def record(self, duration, filename) -> Path:
        return Recorder(self, filename).record(duration)

    def download_and_delete_latest_recording(self, filename: str) -> Path:
        base_url = f"http://{self.ip_address}:{WEB_REMOTE_CONTROL_PORT}"
        response = requests.get(f"{base_url}/recordings.json", timeout=15)
        response.raise_for_status()
        recordings = response.json()
        recording_url = f"{base_url}/recordings/{recordings[0]['name']}"
        recording_file = FILES_DIR / filename
        with requests.get(recording_url, timeout=60, stream=True) as response:
            response.raise_for_status()
            with recording_file.open("wb") as fout:
                for chunk in response.iter_content(1_000_000):
                    fout.write(chunk)
        response = requests.delete(recording_url, timeout=15)
        response.raise_for_status()
        return recording_file

    def ping(self):
        self._get_settings()

    def use_media_relay(self, ip_address: str):
        self._tester_media_ip_address = ip_address
        self._device_media_ip_address = ip_address

    def tester_rist_url(self, port: int = TESTER_RIST_PORT) -> str:
        return f"rist://{self._tester_media_ip_address}:{port}"

    def tester_rtmp_url(self, path: str) -> str:
        return f"rtmp://{self._tester_media_ip_address}:{TESTER_RTMP_PORT}/{path}"

    def tester_rtsp_url(self, path: str) -> str:
        return f"rtsp://{self._tester_media_ip_address}:{TESTER_RTSP_PORT}/{path}"

    def tester_srt_url(self, port: int) -> str:
        return f"srt://{self._tester_media_ip_address}:{port}"

    def tester_srt_publish_url(self, name: str, passphrase: str | None = None) -> str:
        url = f"{self.tester_srt_url(TESTER_SRT_PORT)}?streamid=publish:{name}"
        if passphrase is not None:
            url += f"&passphrase={passphrase}"
        return url

    def tester_whip_url(self, path: str) -> str:
        return f"whip://{self._tester_media_ip_address}:{TESTER_WEBRTC_PORT}/{path}/whip"

    def tester_whep_url(self, path: str) -> str:
        return f"http://{self._tester_media_ip_address}:{TESTER_WEBRTC_PORT}/{path}/whep"

    def ingest_rtmp_url(self, stream_key: str = "1") -> str:
        return f"rtmp://{self._device_media_ip_address}:{RTMP_SERVER_PORT}/live/{stream_key}"

    def ingest_srt_url(self, stream_id: str = "1") -> str:
        return f"srt://{self._device_media_ip_address}:{SRT_SERVER_PORT}?streamid={stream_id}"

    def ingest_whip_url(self, stream_key: str = "1") -> str:
        return f"http://{self._device_media_ip_address}:{WHIP_SERVER_PORT}/whip/stream/{stream_key}"

    def ingest_rist_url(self, virtual_destination_port: int = 1) -> str:
        return (
            f"rist://{self._device_media_ip_address}:{RIST_SERVER_PORT}"
            f"?virt-dst-port={virtual_destination_port}"
        )

    def wait_for_tcp_ports(self, *ports: int, timeout: float = 30):
        for port in ports:

            def check(port=port) -> bool:
                with socket.socket() as sock:
                    sock.settimeout(1)
                    return sock.connect_ex((self._device_media_ip_address, port)) == 0

            wait_until(check, f"TCP port {port} to accept connections", timeout=timeout)

    def has_capability(self, capability: Capability) -> bool:
        return capability in self._capabilities

    def has_moving_picture(self) -> bool:
        return self._moving_picture

    def wait_for_ingests(
        self,
        bitrate: Range,
        total_bytes,
        number_of_ingests,
        timeout: float = 60,
    ):
        accumulated_total_bytes = 0.0
        previous_total_bytes = self.get_ingests_status().total_bytes

        def check() -> bool:
            nonlocal accumulated_total_bytes, previous_total_bytes
            status = self.get_ingests_status()
            delta = status.total_bytes - previous_total_bytes
            if delta > 0:
                accumulated_total_bytes += delta
            previous_total_bytes = status.total_bytes
            return (
                bitrate.minimum <= status.bitrate <= bitrate.maximum
                and accumulated_total_bytes >= total_bytes
                and status.number_of_ingests == number_of_ingests
            )

        wait_until(check, "ingests to reach wanted values", timeout=timeout)

    def wait_for_bitrate(self, minimum_bitrate, maximum_bitrate, multi_streaming, total_bytes):
        def check() -> bool:
            status = parse_bitrate_status(self.get_status_top_right()["bitrate"]["message"])
            return (
                status is not None
                and minimum_bitrate <= status.bitrate <= maximum_bitrate
                and status.multi_streaming == multi_streaming
                and status.total_bytes >= total_bytes
            )

        wait_until(check, "bitrate to reach wanted value", timeout=60)

    def get_status(self):
        return self._request({"getStatus": {}})["data"]["getStatus"]

    def get_status_top_right(self):
        return self.get_status()["topRight"]

    def get_camera_status(self) -> str:
        return self.get_status()["topLeft"]["camera"]["message"]

    def is_muted(self) -> bool:
        return self.get_status()["general"]["isMuted"]

    def get_ingests_status(self) -> "IngestsStatus":
        return parse_ingests_status(self.get_status_top_right()["rtmpServer"]["message"])

    def _create_chat_message(self, text: str, is_moderator: bool):
        self._chat_message_id = max(self._chat_message_id + 1, int(time.time() * 1000))
        return {
            "id": self._chat_message_id,
            "platform": {"twitch": {}},
            "displayName": "Tester",
            "user": "tester",
            "userBadges": [],
            "segments": [{"id": index, "text": f"{word} "} for index, word in enumerate(text.split())],
            "timestamp": time.strftime("%H:%M"),
            "isAction": False,
            "isModerator": is_moderator,
            "isSubscriber": False,
            "isOwner": False,
        }

    def _request(self, data):
        return make_client_request(self._remote_control_port, data)

    def _get_settings(self):
        return self._request({"getSettings": {}})["data"]["getSettings"]["data"]

    def _get_settings_id(self, kind: str, name: str) -> str:
        for item in self._get_settings()[kind]:
            if item["name"] == name:
                return item["id"]
        raise Exception(f"Unknown {kind} item {name}")

    def _wait_until_streamer_is_connected(self):
        LOGGER.info(
            "Waiting for %s's remote control streamer to connect to port %d...",
            self._device_name,
            self._remote_control_port,
        )

        def check() -> bool:
            self.ping()
            return True

        wait_until(check, "streamer to connect", timeout=60, ignore_errors=True)
        LOGGER.info("Remote control streamer connected")


@dataclass
class IngestsStatus:
    bitrate: float
    total_bytes: float
    number_of_ingests: int


@dataclass
class BitrateStatus:
    bitrate: float
    multi_streaming: str | None
    total_bytes: float


def parse_ingests_status(message: str) -> IngestsStatus:
    mo = RE_INGESTS_STATUS.match(message)
    if mo:
        return IngestsStatus(
            bitrate=parse_bitrate(mo.group(1), mo.group(2)),
            total_bytes=parse_total_bytes(mo.group(3), mo.group(4)),
            number_of_ingests=int(mo.group(5)),
        )
    if message.isdigit():
        return IngestsStatus(bitrate=0, total_bytes=0, number_of_ingests=int(message))
    raise Exception(f"Ingests status has wrong format: {message}")


def parse_bitrate_status(message: str) -> BitrateStatus | None:
    mo = RE_BITRATE_STATUS.match(message)
    if mo is None:
        return None
    return BitrateStatus(
        bitrate=parse_bitrate(mo.group(1), mo.group(2)),
        multi_streaming=mo.group(4),
        total_bytes=parse_total_bytes(mo.group(5), mo.group(6)),
    )


def parse_bitrate(value, unit) -> float:
    return _parse_value(value, unit, BITRATE_UNITS, "bitrate")


def parse_total_bytes(value, unit) -> float:
    return _parse_value(value, unit, TOTAL_BYTES_UNITS, "total bytes")


def parse_uptime(uptime: str) -> float | None:
    matches = RE_UPTIME_STATUS.findall(uptime)
    if not matches:
        return None
    return sum(int(value) * UPTIME_UNITS[unit] for value, unit in matches)


def _parse_value(value, unit, units, kind) -> float:
    scale = units.get(unit.lower())
    if scale is None:
        raise Exception(f"Unsupported {kind} unit '{unit}' in '{value} {unit}'")
    return float(value.replace(",", ".")) * scale


class Recorder:
    def __init__(self, moblin: Moblin, filename: str):
        self.recording = Path()
        self._moblin = moblin
        self._filename = filename

    def __enter__(self):
        self._moblin.start_recording()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self._moblin.stop_recording()
        self.recording = self._moblin.download_and_delete_latest_recording(self._filename)

    def record(self, seconds: float) -> Path:
        """Record for given number of seconds and return the downloaded recording."""
        with self:
            time.sleep(seconds)
        return self.recording
