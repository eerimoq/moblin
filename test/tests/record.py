from fractions import Fraction
import logging
import time

from utils.ffmpeg import ffprobe
from utils.moblin import Moblin
from utils.test_case import TestCase

LOGGER = logging.getLogger(__name__)


class RecordH264(TestCase):
    """Record a 10 seconds H.264 video."""

    def run(self):
        self.moblin.set_scene("Front")
        self.moblin.set_stream("Record H.264")
        self.moblin.start_recording()
        time.sleep(10)
        self.moblin.stop_recording()
        recording_file = self.moblin.download_and_delete_latest_recording(
            "RecordH264.mp4"
        )
        recording_metadata = ffprobe(recording_file)
        self.assert_equal(recording_metadata.video.codec, "h264")
        self.assert_greater(recording_metadata.video.fps, Fraction("29/1"))
        self.assert_less(recording_metadata.video.fps, Fraction("31/1"))
        self.assert_equal(recording_metadata.audio.codec, "aac")
        self.assert_greater(recording_metadata.format.duration, 8)
        self.assert_less(recording_metadata.format.duration, 12)


class RecordH265(TestCase):
    """Record a 10 seconds H.265 video."""

    def run(self):
        self.moblin.set_scene("Front")
        self.moblin.set_stream("Record H.265")
        self.moblin.start_recording()
        time.sleep(10)
        self.moblin.stop_recording()
        recording_file = self.moblin.download_and_delete_latest_recording(
            "RecordH265.mp4"
        )
        recording_metadata = ffprobe(recording_file)
        self.assert_equal(recording_metadata.video.codec, "hevc")
        self.assert_greater(recording_metadata.video.fps, Fraction("29/1"))
        self.assert_less(recording_metadata.video.fps, Fraction("31/1"))
        self.assert_equal(recording_metadata.audio.codec, "aac")
        self.assert_greater(recording_metadata.format.duration, 8)
        self.assert_less(recording_metadata.format.duration, 12)


def tests(moblin: Moblin):
    return [
        RecordH264(moblin),
        RecordH265(moblin),
    ]
