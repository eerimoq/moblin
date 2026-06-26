import logging
import subprocess
import time
from .utils import log_output

LOGGER = logging.getLogger(__name__)


class Moblin:
    def __init__(self, remote_control_port, remote_control_password):
        self._remote_control_port = remote_control_port
        self._remote_control_password = remote_control_password
        self._server = None

    def __enter__(self):
        self._server = subprocess.Popen(
            [
                "moblin_assistant",
                "--port",
                str(self._remote_control_port),
                "run",
                "--password",
                self._remote_control_password,
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

    def go_live(self):
        self._execute("go_live")

    def end(self):
        self._execute("end")

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
