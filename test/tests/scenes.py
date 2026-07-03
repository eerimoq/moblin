from fractions import Fraction
import time
import systest

from utils.ffmpeg import ffprobe
from utils.moblin import Moblin
from utils.test_case import TestCase


class SceneSwitchMultipleTimes(TestCase):
    """Switch between two scenes a few times."""

    def run(self):
        for _ in range(10):
            self.moblin.set_scene("Screen")
            self.moblin.set_scene("Front")


class ScenePiPBackFront(TestCase):
    """A picture in picture scene with full screen back camera and small front camera in
    bottom right. Record for a few seconds and validate the recording.

    """

    def run(self):
        if "pip" not in self.moblin.capabilities:
            raise systest.TestCaseSkippedError("PiP not supported.")
        self.moblin.set_scene("PiP")
        time.sleep(1)
        self.moblin.start_recording()
        time.sleep(10)
        self.moblin.stop_recording()
        recording_file = self.moblin.download_and_delete_latest_recording(
            "ScenePiPBackFront.mp4"
        )
        recording_metadata = ffprobe(recording_file)
        self.assert_equal(recording_metadata.video.codec, "hevc")
        self.assert_greater(recording_metadata.video.fps, Fraction("29/1"))
        self.assert_less(recording_metadata.video.fps, Fraction("31/1"))
        self.assert_equal(recording_metadata.audio.codec, "aac")
        self.assert_greater(recording_metadata.format.duration, 8)
        self.assert_less(recording_metadata.format.duration, 12)


def tests(moblin: Moblin):
    return [SceneSwitchMultipleTimes(moblin), ScenePiPBackFront(moblin)]
