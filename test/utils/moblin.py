import subprocess
import time

REMOTE_CONTROL_PORT = "2345"


class Moblin:
    def __init__(self):
        self._server = None

    def __enter__(self):
        self._server = subprocess.Popen(
            [
                "moblin_assistant",
                "--port",
                REMOTE_CONTROL_PORT,
                "run",
                "--password",
                "1234",
            ]
        )
        self._wait_until_streamer_is_connected()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self._server.kill()

    def go_live(self):
        self._execute("go_live")

    def get_settings(self):
        self._execute("get_settings")

    def _execute(self, command):
        subprocess.run(
            ["moblin_assistant", "--port", REMOTE_CONTROL_PORT, command], check=True
        )

    def _wait_until_streamer_is_connected(self):
        while True:
            try:
                self.get_settings()
                break
            except Exception:
                time.sleep(0.05)

