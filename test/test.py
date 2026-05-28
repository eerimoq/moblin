import logging
import subprocess
import time
import systest

REMOTE_CONTROL_PORT = "2345"
LOGGER = logging.getLogger(__name__)


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


class MediaMtx:
    def __init__(self):
        self._server = None

    def __enter__(self):
        self._server = subprocess.Popen(["mediamtx"])
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self._server.kill()


class Ffmpeg:
    def __init__(self):
        self._server = None

    def __enter__(self):
        self._server = subprocess.Popen(["ffmpeg"])
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self._server.kill()


class RtmpFromMoblinToMediaMtx(systest.TestCase):
    def __init__(self, moblin: Moblin):
        super().__init__()
        self.moblin = moblin

    def run(self):
        with MediaMtx():
            self.moblin.go_live()


def main():
    sequencer = systest.setup("all")

    with Moblin() as moblin:
        sequencer.run(RtmpFromMoblinToMediaMtx(moblin))

    sequencer.report_and_exit()


main()
