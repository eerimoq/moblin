import logging
import subprocess
import time
from pathlib import Path
import requests
from .utils import log_output

LOGGER = logging.getLogger(__name__)


class Moblin:
    def __init__(self, remote_control_port, ip_address):
        self._remote_control_port = remote_control_port
        self._server = None
        self.ip_address = ip_address

    def __enter__(self):
        self._server = subprocess.Popen(
            [
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
        log_output(self._server.stdout, LOGGER)
        log_output(self._server.stderr, LOGGER)
        try:
            self._wait_until_streamer_is_connected()
        except BaseException:
            self._server.kill()
            self._server.wait()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        LOGGER.info("exit")
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

    def download_and_delete_latest_recording(self):
        response = requests.get(
            f"http://{self.ip_address}:1180/recordings.json", timeout=15
        )
        response.raise_for_status()
        recordings = response.json()
        recording_name = recordings[0]["name"]
        recording_url = f"http://{self.ip_address}:1180/recordings/{recording_name}"
        response = requests.get(recording_url, timeout=15)
        response.raise_for_status()
        recording_file = Path(recording_name)
        recording_file.write_bytes(response.content)
        response = requests.delete(recording_url, timeout=15)
        response.raise_for_status()
        return recording_file

    def get_settings(self):
        self._execute("get_settings")

    def wait_for_ingests(self, number_of_ingests):
        pass

    def _execute(self, command, *args):
        subprocess.run(
            [
                "moblin_assistant",
                "--port",
                str(self._remote_control_port),
                command,
                *args,
            ],
            check=True,
            capture_output=True,
        )

    def _wait_until_streamer_is_connected(self):
        end_time = time.monotonic() + 15
        while time.monotonic() < end_time:
            try:
                self.get_settings()
                LOGGER.info("Remote control streamer to connected")
                return
            except Exception:
                LOGGER.info(
                    "Waiting for remote control streamer to connect to port %d",
                    self._remote_control_port,
                )
                time.sleep(1)
        raise Exception("Timeout waiting for streamer to connect")
