import json
import logging
import subprocess
import time
from pathlib import Path
import re
import requests

from .config import Config
from .utils import log_output

LOGGER = logging.getLogger(__name__)
LOGGER_ASSISTANT = logging.getLogger(__name__ + ".assistant")
RE_INGESTS_STATUS = re.compile(r"(\S+) (\S+) \((\S+) (\S+)\) (\S+)")
RE_BITRATE_STATUS = re.compile(r"(\S+) (\S+) ((\S+) )?\((\S+) (\S+)\)")


class Moblin:
    def __init__(self, config: Config):
        self._device_name = config.device_name()
        self._remote_control_port = config.remote_control_port()
        self._server = None
        self.ip_address = config.moblin_ip_address()
        self.capabilities = config.capabilities()

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

    def set_stream(self, name):
        try:
            self._execute("set_stream", name)
        except subprocess.CalledProcessError:
            time.sleep(3)

    def set_scene(self, name):
        self._execute("set_scene", name)

    def go_live(self):
        self._execute("go_live")

    def end(self):
        self._execute("end")

    def start_recording(self):
        self._execute("start_recording")

    def stop_recording(self):
        self._execute("stop_recording")

    def download_and_delete_latest_recording(self, filename: str) -> Path:
        response = requests.get(
            f"http://{self.ip_address}:1180/recordings.json", timeout=15
        )
        response.raise_for_status()
        recordings = response.json()
        recording_url = (
            f"http://{self.ip_address}:1180/recordings/{recordings[0]["name"]}"
        )
        response = requests.get(recording_url, timeout=15)
        response.raise_for_status()
        recording_file = Path("files") / filename
        recording_file.write_bytes(response.content)
        response = requests.delete(recording_url, timeout=15)
        response.raise_for_status()
        return recording_file

    def get_settings(self):
        self._execute("get_settings")

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
                self.get_settings()
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
        if not mo:
            raise Exception(f"Ingests status has wrong format: {ingests_status}")
        bitrate = parse_bitrate(mo.group(1), mo.group(2))
        total_bytes = parse_total_bytes(mo.group(3), mo.group(4))
        number_of_ingests = int(mo.group(5))
        return bitrate, total_bytes, number_of_ingests


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
