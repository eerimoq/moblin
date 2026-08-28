import json
import logging
import re
import socket
import sys
import tempfile
import threading
import time
from base64 import b64encode
from collections import defaultdict
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path

import requests
from moblin_assistant import make_client_request
from systest import ManagedProcess
from systest import wait_until
from websockets.sync.client import ClientConnection
from websockets.sync.client import connect

from .arduino import Arduino
from .config import REMOTE_CONTROL_PASSWORD
from .config import RIST_SERVER_PORT
from .config import RTMP_SERVER_PORT
from .config import SRT_SERVER_PORT
from .config import TESTER_RIST_PORT
from .config import TESTER_RTMP_PORT
from .config import TESTER_RTSP_PORT
from .config import TESTER_SRT_PORT
from .config import TESTER_SRTLA_PORT
from .config import TESTER_WEBRTC_PORT
from .config import WEB_REMOTE_CONTROL_PORT
from .config import WHIP_SERVER_PORT
from .config import Capability
from .config import Config
from .generate_device_settings import SceneName
from .generate_device_settings import base_settings
from .generate_device_settings import create_settings_file
from .utils import FILES_DIR
from .utils import Range

LOGGER = logging.getLogger(__name__)
LOGGER_ASSISTANT = logging.getLogger(__name__ + ".assistant")
LOGGER_EVENTS = logging.getLogger(__name__ + ".events")
RE_INGESTS_STATUS = re.compile(r"(\S+) (\S+) \((\S+) (\S+)\) (\S+)")
RE_BITRATE_STATUS = re.compile(r"(\S+) (\S+) ((\S+) )?\((\S+) (\S+)\)")
RE_UPTIME_STATUS = re.compile(r"(\d+)\s*([dhms])")
RE_VIDEO_DECODE_ERROR = re.compile(r"video-decoder: (\S+): Failed to decode (\d+) frame\(s\)")
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
            self._counts[mo.group(1)] += int(mo.group(2))

    def counts(self) -> dict[str, int]:
        with self._lock:
            return dict(self._counts)


@dataclass
class BufferedBuffersCounts:
    duplicated: dict[str, int]
    dropped: dict[str, int]


class BufferedBuffers:
    def __init__(self, media: str):
        self._re = re.compile(rf"buffered-{media}: (.+?): (\d+) duplicated and (\d+) dropped buffers")
        self._lock = threading.Lock()
        self._duplicated: defaultdict[str, int] = defaultdict(int)
        self._dropped: defaultdict[str, int] = defaultdict(int)

    def handle_log_entry(self, entry: str):
        mo = self._re.search(entry)
        if mo is None:
            return
        with self._lock:
            self._duplicated[mo.group(1)] += int(mo.group(2))
            self._dropped[mo.group(1)] += int(mo.group(3))

    def counts(self) -> BufferedBuffersCounts:
        with self._lock:
            return BufferedBuffersCounts(dict(self._duplicated), dict(self._dropped))


class AssistantEvents:
    def __init__(self, port: int, log_entry_observer: Callable[[str], None]):
        self._port = port
        self._log_entry_observer = log_entry_observer
        self._stopped = threading.Event()
        self._connection: ClientConnection | None = None
        self._thread = threading.Thread(target=self._listen, daemon=True)
        self._state_lock = threading.Lock()
        self._state: dict = {}

    def state(self) -> dict:
        with self._state_lock:
            return dict(self._state)

    def start(self):
        self._thread.start()

    def stop(self):
        self._stopped.set()
        connection = self._connection
        if connection is not None:
            connection.close()
        self._thread.join(timeout=5)

    def _listen(self):
        while not self._stopped.is_set():
            try:
                with connect(f"ws://localhost:{self._port}/events", max_size=None) as connection:
                    self._connection = connection
                    for message in connection:
                        self._handle_message(message)
            except Exception:
                pass
            finally:
                self._connection = None
            self._stopped.wait(1)

    def _handle_message(self, message):
        for kind, data in json.loads(message).items():
            if kind == "log":
                entry = data["entry"]
                LOGGER_EVENTS.debug("%s", entry)
                self._log_entry_observer(entry)
            else:
                if kind == "state":
                    with self._state_lock:
                        self._state.update(data["data"])
                LOGGER_EVENTS.debug("%s: %s", kind, data)


class Moblin:
    def __init__(
        self,
        config: Config,
        device_name: str,
        arduino: Arduino | None = None,
        moving_picture: bool = False,
        dji_camera: bool = False,
        interactive: bool = False,
        ip_address: str | None = None,
        remote_control_port: int | None = None,
    ):
        self.config = config
        self.device_name = device_name
        self.arduino = arduino
        self.video_decode_errors = VideoDecodeErrors()
        self.buffered_video_buffers = BufferedBuffers("video")
        self.buffered_audio_buffers = BufferedBuffers("audio")
        self._remote_control_port = (
            remote_control_port if remote_control_port is not None else config.remote_control_port()
        )
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
            ready=self._wait_until_streamer_is_connected,
        )
        self._events = AssistantEvents(self._remote_control_port, self._handle_log_entry)
        self.ip_address = ip_address if ip_address is not None else config.moblin_ip_address(device_name)
        self._tester_ip_address = config.tester_ip_address()
        self._tester_media_ip_address = self._tester_ip_address
        self._device_media_ip_address = self.ip_address
        self._interactive = interactive
        self._moving_picture = moving_picture
        self._dji_camera = dji_camera
        self._chat_message_id = 0

    def __enter__(self):
        self._server.start()
        self._events.start()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self._events.stop()
        self._server.stop()

    def _handle_log_entry(self, entry: str):
        self.video_decode_errors.handle_log_entry(entry)
        self.buffered_video_buffers.handle_log_entry(entry)
        self.buffered_audio_buffers.handle_log_entry(entry)

    def import_settings(self, overrides, files: dict[str, Path] | None = None):
        settings = base_settings(self.config, self._remote_control_port)
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

    def set_mic(self, name):
        self._request({"setMic": {"id": self._get_settings_id("mics", name)}})

    def set_main_mic(self):
        self.set_mic(self.get_mics()[0]["name"])

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

    def set_gimbal_tracking(self, on: bool):
        self._request({"setGimbalTracking": {"on": on}})

    def set_gimbal_movement(self, x: float, y: float):
        self._request({"setGimbalMovement": {"x": x, "y": y}})

    def animate_gimbal(self, motion: str):
        self._request({"animateGimbal": {"motion": {motion: {}}}})

    def save_gimbal_preset(self):
        self._request({"saveGimbalPreset": {}})

    def move_to_gimbal_preset(self, preset_id: str):
        self._request({"moveToGimbalPreset": {"id": preset_id}})

    def wait_for_gimbal_tracking(self, on: bool):
        wait_until(
            lambda: self.get_state().get("gimbalTracking") == on,
            f"gimbal tracking to be {on}",
        )

    def wait_for_gimbal_presets(self, number_of_presets: int) -> list[dict]:
        wait_until(
            lambda: len(self.get_state().get("gimbalPresets") or []) == number_of_presets,
            f"{number_of_presets} gimbal preset(s)",
        )
        return self.get_state()["gimbalPresets"]

    def get_state(self) -> dict:
        return self._events.state()

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
        base_url = self._web_remote_control_url()
        recordings = self._get_recordings()
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

    def delete_all_recordings(self):
        base_url = self._web_remote_control_url()
        for recording in self._get_recordings():
            response = requests.delete(f"{base_url}/recordings/{recording['name']}", timeout=15)
            response.raise_for_status()

    def _web_remote_control_url(self) -> str:
        return f"http://{self.ip_address}:{WEB_REMOTE_CONTROL_PORT}"

    def _get_recordings(self) -> list:
        response = requests.get(f"{self._web_remote_control_url()}/recordings.json", timeout=15)
        response.raise_for_status()
        return response.json()

    def ping(self):
        self._get_settings()

    def use_media_relay(self, ip_address: str):
        self._tester_media_ip_address = ip_address
        self._device_media_ip_address = ip_address

    def tester_rist_url(self, port: int = TESTER_RIST_PORT) -> str:
        return f"rist://{self._tester_media_ip_address}:{port}"

    def tester_rtmp_url(self, path: str, port: int = TESTER_RTMP_PORT) -> str:
        return f"rtmp://{self._tester_media_ip_address}:{port}/{path}"

    def tester_rtsp_url(self, path: str) -> str:
        return f"rtsp://{self._tester_media_ip_address}:{TESTER_RTSP_PORT}/{path}"

    def tester_srt_url(self, port: int) -> str:
        return f"srt://{self._tester_media_ip_address}:{port}"

    def tester_srt_publish_url(self, name: str, passphrase: str | None = None) -> str:
        url = f"{self.tester_srt_url(TESTER_SRT_PORT)}?streamid=publish:{name}"
        if passphrase is not None:
            url += f"&passphrase={passphrase}"
        return url

    def tester_srtla_url(self, stream_id: str) -> str:
        return f"srtla://{self._tester_media_ip_address}:{TESTER_SRTLA_PORT}?streamid={stream_id}"

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

    def wait_for_tcp_ports(self, *ports: int, ip_address: str | None = None):
        address = ip_address if ip_address is not None else self._device_media_ip_address
        for port in ports:

            def check(port=port) -> bool:
                with socket.socket() as sock:
                    sock.settimeout(1)
                    return sock.connect_ex((address, port)) == 0

            wait_until(check, f"TCP port {port} on {address} to accept connections")

    @property
    def secondary_ip_address(self) -> str | None:
        return self.config.moblin_secondary_ip_address(self.device_name)

    def has_capability(self, capability: Capability) -> bool:
        return capability in self.config.capabilities(self.device_name)

    def has_secondary_ip_address(self) -> bool:
        return self.secondary_ip_address is not None

    def has_moving_picture(self) -> bool:
        return self._moving_picture

    def has_dji_camera(self) -> bool:
        return self._dji_camera

    def is_interactive(self) -> bool:
        return self._interactive

    def wait_for_ingests(
        self,
        bitrate: Range,
        total_bytes,
        number_of_ingests,
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

        wait_until(check, "ingests to reach wanted values")

    def wait_for_dji_devices_streaming(self, number_of_devices: int = 1):
        def check() -> bool:
            status = self.get_status_top_right().get("djiDevices")
            return status is not None and len(status["message"].split(",")) == number_of_devices

        wait_until(check, "DJI devices to start streaming")

    def wait_for_bonding_connections(self, number_of_connections: int):
        def check() -> bool:
            status = self.get_status_top_right().get("srtla")
            return status is not None and len(status["message"].split(",")) == number_of_connections

        wait_until(check, "bonding connections to be established")

    def wait_for_bitrate(self, minimum_bitrate, maximum_bitrate, multi_streaming, total_bytes):
        def check() -> bool:
            status = parse_bitrate_status(self.get_status_top_right()["bitrate"]["message"])
            return (
                status is not None
                and minimum_bitrate <= status.bitrate <= maximum_bitrate
                and status.multi_streaming == multi_streaming
                and status.total_bytes >= total_bytes
            )

        wait_until(check, "bitrate to reach wanted value")

    def get_status(self):
        return self._request({"getStatus": {}})["data"]["getStatus"]

    def get_status_top_right(self):
        return self.get_status()["topRight"]

    def get_camera_status(self) -> str:
        return self.get_status()["topLeft"]["camera"]["message"]

    def get_mic(self) -> str:
        return self.get_status()["topLeft"]["mic"]["message"]

    def get_number_of_audio_channels(self) -> int:
        return self.get_status_top_right()["audioInfo"]["numberOfAudioChannels"]

    def get_mics(self) -> list[dict]:
        return self._get_settings()["mics"]

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
            self.device_name,
            self._remote_control_port,
        )

        def check() -> bool:
            self.ping()
            return True

        wait_until(check, "streamer to connect", ignore_errors=True)
        LOGGER.info("Remote control streamer connected")


def create_receiver(config: Config) -> Moblin:
    return Moblin(
        config,
        "receiver",
        ip_address=config.tester_ip_address(),
        remote_control_port=config.receiver_remote_control_port(),
    )


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
