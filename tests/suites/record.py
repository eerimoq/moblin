import logging
import time

from utils.generate_device_settings import FRONT_SCENE_SETTINGS
from utils.moblin import Moblin
from utils.test_case import TestCase

LOGGER = logging.getLogger(__name__)


class Record(TestCase):
    """Record a 10 seconds video."""

    def __init__(self, moblin: Moblin, video_codec: str, resolution: str, fps: int):
        super().__init__(moblin, f"Record{video_codec}-{resolution}@{fps}")
        self._video_codec = video_codec
        self._resolution = resolution
        self._fps = fps

    def setup(self):
        if self._fps != 30:
            self.skip_if_missing_capability("record")
        self.skip_if_no_moving_picture()
        self.moving_picture_on()
        self.moblin.import_settings(
            overrides={
                "streams": [
                    {
                        "enabled": True,
                        "fps": self._fps,
                        "resolution": self._resolution,
                        "recording": {"videoCodec": self._get_video_codec()},
                    }
                ],
                "scenes": [FRONT_SCENE_SETTINGS],
                "widgets": [],
            }
        )

    def run(self):
        time.sleep(1)
        recording_file = self.moblin.record(
            10, f"Record-{self._video_codec}-{self._resolution}@{self._fps}.mp4"
        )
        self.assert_recording(
            recording_file,
            has_qr_codes=False,
            width=self._get_width(),
            height=self._get_height(),
            fps=self._fps,
            video_codec=self._get_ffmpeg_video_codec(),
        )

    def _get_video_codec(self):
        if self._video_codec == "H.264":
            return "H.264/AVC"
        else:
            return "H.265/HEVC"

    def _get_ffmpeg_video_codec(self):
        if self._video_codec == "H.264":
            return "h264"
        else:
            return "hevc"

    def _get_width(self):
        return {"1920x1080": 1920, "2560x1440": 2560, "3840x2160": 3840}[
            self._resolution
        ]

    def _get_height(self):
        return {"1920x1080": 1080, "2560x1440": 1440, "3840x2160": 2160}[
            self._resolution
        ]


def tests(moblin: Moblin):
    test_cases = [
        Record(moblin, video_codec="H.264", resolution="1920x1080", fps=30),
    ]
    for resolution in ["1920x1080", "2560x1440", "3840x2160"]:
        for fps in [30, 60]:
            test_cases.append(
                Record(moblin, video_codec="H.265", resolution=resolution, fps=fps)
            )
    return test_cases
