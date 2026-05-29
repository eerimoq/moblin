import logging
import subprocess
import threading
import time

LOGGER = logging.getLogger(__name__)
REMOTE_CONTROL_PORT = "2345"


def _log_stream(stream):
    try:
        for line in stream:
            LOGGER.debug(line.rstrip())
    except Exception:
        pass


def _log_output(stream):
    threading.Thread(target=_log_stream, args=(stream,), daemon=True).start()


class Moblin:
    def __init__(self):
        self._server = None

    def __enter__(self):
        LOGGER.info("Starting")
        self._server = subprocess.Popen(
            [
                "moblin_assistant",
                "--port",
                REMOTE_CONTROL_PORT,
                "run",
                "--password",
                "1234",
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        _log_output(self._server.stdout)
        _log_output(self._server.stderr)
        try:
            self._wait_until_streamer_is_connected()
        finally:
            self._server.kill()
        LOGGER.info("Started")
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        LOGGER.info("exit")
        self._server.kill()

    def go_live(self):
        self._execute("go_live")

    def get_settings(self):
        self._execute("get_settings")

    def _execute(self, command):
        subprocess.run(
            ["moblin_assistant", "--port", REMOTE_CONTROL_PORT, command],
            check=True,
            capture_output=True,
        )

    def _wait_until_streamer_is_connected(self):
        end_time = time.monotonic() + 15
        while time.monotonic() < end_time:
            try:
                self.get_settings()
                break
            except Exception:
                time.sleep(1)
        else:
            raise Exception("Timeout waiting for streamer to connect")
