import logging
import time
import systest

from utils.utils import Crop
from utils.moblin import Moblin
from utils.test_case import TestCase

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
        self.assert_recording(
            recording_file,
            has_qr_codes=False,
            duplicated_frames_crops=[
                # Top left
                Crop(x=0, y=0, width=800, height=500),
                # Bottom right
                Crop(x=1120, y=580, width=800, height=500),
            ],
        )


def tests(moblin: Moblin):
    return [SceneSwitchMultipleTimes(moblin), ScenePiPBackFront(moblin)]
