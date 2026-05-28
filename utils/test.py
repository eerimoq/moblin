import logging
import systest
import subprocess
import time


REMOTE_CONTROL_PORT = '2345'
LOGGER = logging.getLogger(__name__)


class Moblin:
    def __enter__(self):
        self._server = subprocess.Popen(["moblin_assistant",
                                         "--port", REMOTE_CONTROL_PORT,
                                         "run",
                                         "--password", "1234"])
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self._server.kill()

    def go_live(self):
        self._execute("go_live")

    def _execute(self, command):
        subprocess.run(["moblin_assistant", "--port", REMOTE_CONTROL_PORT, command])


class MediaMtx:
    def __enter__(self):
        self._server = subprocess.Popen(["mediamtx"])
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self._server.kill()


class Ffmpeg:
    def __enter__(self):
        self._server = subprocess.Popen(["ffmpeg"])
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self._server.kill()


class RtmpFromMoblinToMediaMtx(systest.TestCase):
    def __init__(self, moblin: Moblin):
        super(RtmpFromMoblinToMediaMtx, self).__init__()
        self.moblin = moblin

    def run(self):
        time.sleep(5)
        self.moblin.go_live()
        time.sleep(1)


def main():
    sequencer = systest.setup("all")

    with Moblin() as moblin:
        sequencer.run(RtmpFromMoblinToMediaMtx(moblin))

    sequencer.report_and_exit()


main()