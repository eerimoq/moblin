import json
import logging
import re
import subprocess
import tempfile
import time
from pathlib import Path

import requests

from .arduino import Arduino
from .config import TESTER_RIST_PORT
from .config import TESTER_RTMP_PORT
from .config import TESTER_RTSP_PORT
from .config import TESTER_SRT_PORT
from .config import WEB_REMOTE_CONTROL_PORT
from .config import Config
from .generate_device_settings import base_settings
from .generate_device_settings import create_settings_file
from .utils import FILES_DIR
from .utils import log_output

LOGGER = logging.getLogger(__name__)
LOGGER_ASSISTANT = logging.getLogger(__name__ + ".assistant")
RE_INGESTS_STATUS = re.compile(r"(\S+) (\S+) \((\S+) (\S+)\) (\S+)")
RE_BITRATE_STATUS = re.compile(r"(\S+) (\S+) ((\S+) )?\((\S+) (\S+)\)")


class Moblin:
    def __init__(self, config: Config, arduino: Arduino | None, moving_picture: bool):
        self.config = config
        self.arduino = arduino
        self._device_name = config.device_name()
        self._remote_control_port = config.remote_control_port()
        self._server = None
        self.ip_address = config.moblin_ip_address()
        self._tester_ip_address = config.tester_ip_address()
        self._capabilities = config.capabilities()
        self._moving_picture = moving_picture

    def __enter__(self):
        self._server = subprocess.Popen(
            [
                "python",
                "-u",
                "-m",
                "moblin_assistant",
                "--port",
                str(self._remote_control_port),
                "run",
                "--password",
                "1234",
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        log_output(self._server.stdout, LOGGER_ASSISTANT)
        log_output(self._server.stderr, LOGGER_ASSISTANT)
        try:
            self._wait_until_streamer_is_connected()
        except BaseException:
            self._server.kill()
            self._server.wait()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        if self._server is not None:
            self._server.kill()
            self._server.wait()

    def import_settings(self, overrides, files: dict[str, Path] | None = None):
        settings = base_settings(self.config.config_toml)
        settings.update(overrides)
        with tempfile.TemporaryDirectory() as settings_dir:
            settings_file = Path(settings_dir) / "settings.zip"
            create_settings_file(settings, settings_file, files)
            try:
                self._execute("import_settings", settings_file)
            except subprocess.CalledProcessError:
                time.sleep(2)

    def set_scene(self, name):
        self._execute("set_scene", name)

    def set_talkback_mic(self, name):
        self._execute("set_talkback_mic", name)

    def go_live(self):
        self._execute("go_live")

    def end(self):
        self._execute("end")

    def start_recording(self):
        self._execute("start_recording")

    def stop_recording(self):
        self._execute("stop_recording")

    def record(self, duration, filename) -> Path:
        return Recorder(self, filename).record(duration)

    def download_and_delete_latest_recording(self, filename: str) -> Path:
        base_url = f"http://{self.ip_address}:{WEB_REMOTE_CONTROL_PORT}"
        response = requests.get(f"{base_url}/recordings.json", timeout=15)
        response.raise_for_status()
        recordings = response.json()
        recording_url = f"{base_url}/recordings/{recordings[0]["name"]}"
        response = requests.get(recording_url, timeout=15)
        response.raise_for_status()
        recording_file = FILES_DIR / filename
        recording_file.write_bytes(response.content)
        response = requests.delete(recording_url, timeout=15)
        response.raise_for_status()
        return recording_file

    def ping(self):
        self._execute("get_settings")

    def tester_rist_url(self, port: int = TESTER_RIST_PORT) -> str:
        return f"rist://{self._tester_ip_address}:{port}"

    def tester_rtmp_url(self, path: str) -> str:
        return f"rtmp://{self._tester_ip_address}:{TESTER_RTMP_PORT}/{path}"

    def tester_rtsp_url(self, path: str) -> str:
        return f"rtsp://{self._tester_ip_address}:{TESTER_RTSP_PORT}/{path}"

    def tester_srt_url(self, port: int) -> str:
        return f"srt://{self._tester_ip_address}:{port}"

    def tester_srt_publish_url(self, name: str, passphrase: str | None = None) -> str:
        url = f"{self.tester_srt_url(TESTER_SRT_PORT)}?streamid=publish:{name}"
        if passphrase is not None:
            url += f"&passphrase={passphrase}"
        return url

    def has_capability(self, name: str) -> bool:
        return name in self._capabilities

    def has_moving_picture(self) -> bool:
        return self._moving_picture

    def wait_for_ingests(
        self, minimim_bitrate, maximum_bitrate, total_bytes, number_of_ingests
    ):
        accumulated_total_bytes = 0
        previous_total_bytes = self._get_ingests_status()[1]
        end_time = time.monotonic() + 60
        while time.monotonic() < end_time:
            time.sleep(1)
            actual_bitrate, actual_total_bytes, actual_number_of_ingests = (
                self._get_ingests_status()
            )
            total_bytes_delta = actual_total_bytes - previous_total_bytes
            if total_bytes_delta > 0:
                accumulated_total_bytes += total_bytes_delta
            previous_total_bytes = actual_total_bytes
            if actual_bitrate < minimim_bitrate or actual_bitrate > maximum_bitrate:
                continue
            if accumulated_total_bytes < total_bytes:
                continue
            if actual_number_of_ingests != number_of_ingests:
                continue
            return
        raise Exception("Timeout waiting for ingests to reach wanted values")

    def wait_for_bitrate(
        self, minimim_bitrate, maximum_bitrate, multi_streaming, total_bytes
    ):
        end_time = time.monotonic() + 60
        while time.monotonic() < end_time:
            time.sleep(1)
            bitrate_status = self.get_status_top_right()["bitrate"]["message"]
            mo = RE_BITRATE_STATUS.match(bitrate_status)
            if mo:
                actual_bitrate = parse_bitrate(mo.group(1), mo.group(2))
                actual_multi_streaming = mo.group(4)
                actual_total_bytes = parse_total_bytes(mo.group(5), mo.group(6))
                if actual_bitrate < minimim_bitrate or actual_bitrate > maximum_bitrate:
                    continue
                if actual_multi_streaming != multi_streaming:
                    continue
                if actual_total_bytes < total_bytes:
                    continue
                return
        raise Exception("Timeout waiting for bitrate to reach wanted value")

    def get_status_top_right(self):
        return json.loads(self._execute("get_status"))["topRight"]

    def _execute(self, command, *args):
        return subprocess.run(
            [
                "moblin_assistant",
                "--port",
                str(self._remote_control_port),
                command,
                *args,
            ],
            check=True,
            capture_output=True,
            text=True,
        ).stdout

    def _wait_until_streamer_is_connected(self):
        end_time = time.monotonic() + 60
        while time.monotonic() < end_time:
            try:
                self.ping()
                LOGGER.info("Remote control streamer connected")
                time.sleep(3)
                return
            except Exception:
                LOGGER.info(
                    "Waiting for %s's remote control streamer to connect to port %d",
                    self._device_name,
                    self._remote_control_port,
                )
                time.sleep(1)
        raise Exception("Timeout waiting for streamer to connect")

    def _get_ingests_status(self):
        ingests_status = self.get_status_top_right()["rtmpServer"]["message"]
        mo = RE_INGESTS_STATUS.match(ingests_status)
        if mo:
            bitrate = parse_bitrate(mo.group(1), mo.group(2))
            total_bytes = parse_total_bytes(mo.group(3), mo.group(4))
            number_of_ingests = int(mo.group(5))
            return bitrate, total_bytes, number_of_ingests
        if ingests_status.isdigit():
            # Only the number of ingests is shown when no ingest is connected.
            return 0, 0, int(ingests_status)
        raise Exception(f"Ingests status has wrong format: {ingests_status}")


def parse_bitrate(value, unit):
    bitrate = float(value.replace(",", "."))
    if unit == "Mbps":
        bitrate *= 1_000_000
    return bitrate


def parse_total_bytes(value, unit):
    total_bytes = float(value.replace(",", "."))
    if unit == "MB":
        total_bytes *= 1_000_000
    return total_bytes


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
        self.recording = self._moblin.download_and_delete_latest_recording(
            self._filename
        )

    def record(self, seconds: float) -> Path:
        """Record for given number of seconds and return the downloaded recording."""
        with self:
            time.sleep(seconds)
        return self.recording
