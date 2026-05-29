import logging
import subprocess
import threading
import time

LOGGER = logging.getLogger(__name__)


def _log_stream(stream):
    try:
        for line in stream:
            LOGGER.debug(line.rstrip())
    except Exception:
        pass


def _log_output(stream):
    threading.Thread(target=_log_stream, args=(stream,), daemon=True).start()


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
        _log_output(self._server.stdout)
        _log_output(self._server.stderr)
        try:
            self._wait_until_streamer_is_connected()
        except BaseException:
            self._server.kill()
            self._server.wait()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        LOGGER.info("exit")
        self._server.kill()
        self._server.wait()

    def set_stream(self, name):
        self._execute(f"set_stream {name}")

    def go_live(self):
        self._execute("go_live")

    def end(self):
        self._execute("end")

    def get_settings(self):
        self._execute("get_settings")

    def wait_for_ingests(self, number_of_ingests):
        pass

    def _execute(self, command):
        subprocess.run(
            ["moblin_assistant", "--port", str(self._remote_control_port), command],
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
