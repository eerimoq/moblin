import logging
import time

from utils.moblin import Moblin
from utils.test_case import TestCase

LOGGER = logging.getLogger(__name__)


class Record(TestCase):
    """Record a 10 seconds video."""

    def __init__(self, moblin: Moblin, video_codec: str):
        super().__init__(moblin, f"Record{video_codec}")
        self._video_codec = video_codec

    def run(self):
        self.moblin.set_scene("Front")
        self.moblin.set_stream(f"Record {self._video_codec}")
        time.sleep(1)
        self.moblin.start_recording()
        time.sleep(10)
        self.moblin.stop_recording()
        recording_file = self.moblin.download_and_delete_latest_recording(
            f"Record-{self._video_codec}.mp4"
        )
        self.assert_recording(
            recording_file,
            has_qr_codes=False,
            video_codec=self._get_ffmpeg_video_codec(),
        )

    def _get_ffmpeg_video_codec(self):
        if self._video_codec == "H.264":
            return "h264"
        else:
            return "hevc"


def tests(moblin: Moblin):
    return [
        Record(moblin, video_codec="H.264"),
        Record(moblin, video_codec="H.265"),
    ]
