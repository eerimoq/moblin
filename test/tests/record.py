import logging
import time

from utils.moblin import Moblin
from utils.test_case import TestCase

LOGGER = logging.getLogger(__name__)


class RecordH264(TestCase):
    """Record a 10 seconds H.264 video."""

    def run(self):
        self.moblin.set_scene("Front")
        self.moblin.set_stream("Record H.264")
        time.sleep(1)
        self.moblin.start_recording()
        time.sleep(10)
        self.moblin.stop_recording()
        recording_file = self.moblin.download_and_delete_latest_recording(
            "RecordH264.mp4"
        )
        self.assert_recording(recording_file, has_qr_codes=False, video_codec="h264")


class RecordH265(TestCase):
    """Record a 10 seconds H.265 video."""

    def run(self):
        self.moblin.set_scene("Front")
        self.moblin.set_stream("Record H.265")
        time.sleep(1)
        self.moblin.start_recording()
        time.sleep(10)
        self.moblin.stop_recording()
        recording_file = self.moblin.download_and_delete_latest_recording(
            "RecordH265.mp4"
        )
        self.assert_recording(recording_file, has_qr_codes=False)


def tests(moblin: Moblin):
    return [
        RecordH264(moblin),
        RecordH265(moblin),
    ]
