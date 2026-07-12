import logging
import time
from pathlib import Path

from utils.ffmpeg import FfmpegServer
from utils.moblin import Moblin
from utils.test_case import TestCase
from utils.utils import Crop

LOGGER = logging.getLogger(__name__)


class SceneSwitchMultipleTimes(TestCase):
    """Switch between two scenes a few times."""

    def run(self):
        for _ in range(10):
            self.moblin.set_scene("Screen")
            self.moblin.set_scene("Front")


class ScenePiPBackFront(TestCase):
    """A picture in picture scene with full screen back camera and small front camera in
    bottom right. Record for a few seconds and validate the recording.

    NOTE: Static scenes will make this test fail!

    """

    def __init__(self, moblin: Moblin, fps: int):
        super().__init__(moblin, f"ScenePiPBackFront{fps}Fps")
        self._fps = fps

    def setup(self):
        self.skip_if_missing_capability("pip")

    def run(self):
        self.moblin.set_stream(f"SRT 5Mbps 1080@{self._fps}")
        self.moblin.set_scene("PiP")
        time.sleep(2)
        self.moblin.start_recording()
        time.sleep(10)
        self.moblin.stop_recording()
        recording_file = self.moblin.download_and_delete_latest_recording(
            f"ScenePiPBackFront{self._fps}.mp4"
        )
        self.assert_recording(
            recording_file,
            has_qr_codes=False,
            duplicated_frames_crops=[
                # Top left
                Crop(x=0, y=0, width=800, height=500),
                # Bottom right
                Crop(x=1120, y=580, width=800, height=500),
            ],
            fps=self._fps,
        )


class ScenewidgetsInBackground(TestCase):
    """Stream in background mode with various widgets showing."""

    def setup(self):
        self.skip_if_missing_capability("background-streaming")

    def run(self):
        filename = Path("files/ScenewidgetsInBackground.ts")
        self.moblin.set_scene("Background streaming")
        with FfmpegServer(url="srt://0.0.0.0:8890?mode=listener", filename=filename):
            self.moblin.set_stream("Background streaming")
            self.moblin.go_live()
            input("Put the app in background and press enter")
            LOGGER.info("Streaming in background for 10 seconds...")
            time.sleep(10)
            self.moblin.end()
            input("Put the app in foreground and press enter")


def tests(moblin: Moblin):
    return [
        SceneSwitchMultipleTimes(moblin),
        ScenePiPBackFront(moblin, fps=30),
        ScenePiPBackFront(moblin, fps=60),
        ScenewidgetsInBackground(moblin),
    ]
