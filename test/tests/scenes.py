import logging
import time
import systest

from utils.moblin import Moblin
from utils.test_case import TestCase
from utils.test_case import RecordTest

LOGGER = logging.getLogger(__name__)


class SceneSwitchMultipleTimes(TestCase):
    """Switch between two scenes a few times."""

    def run(self):
        for _ in range(10):
            self.moblin.set_scene("Screen")
            self.moblin.set_scene("Front")


class ScenePiPBackFront(RecordTest):
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
        try:
            self.assert_recording(recording_file)
        except systest.TestCaseFailedError as e:
            raise systest.TestCaseXFailedError(str(e))


def tests(moblin: Moblin):
    return [SceneSwitchMultipleTimes(moblin), ScenePiPBackFront(moblin)]
