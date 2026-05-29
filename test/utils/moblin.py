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
        time.sleep(1)
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self._server.kill()

    def go_live(self):
        self._execute("go_live")

    def _execute(self, command):
        subprocess.run(
            ["moblin_assistant", "--port", REMOTE_CONTROL_PORT, command], check=True
        )
