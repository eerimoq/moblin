import logging
import time

from utils.config import Capability
from utils.ffmpeg import FfmpegVideoCodec
from utils.generate_device_settings import FRONT_SCENE_SETTINGS
from utils.generate_device_settings import Resolution
from utils.generate_device_settings import VideoCodec
from utils.moblin import Moblin
from utils.test_case import TestCase

LOGGER = logging.getLogger(__name__)
FFMPEG_VIDEO_CODECS = {
    VideoCodec.H264: FfmpegVideoCodec.H264,
    VideoCodec.H265: FfmpegVideoCodec.HEVC,
}


class Record(TestCase):
    """Record a 10 seconds video."""

    def __init__(
        self, moblin: Moblin, video_codec: VideoCodec, resolution: Resolution, fps: int
    ):
        super().__init__(moblin, f"Record{video_codec.name}-{resolution}@{fps}")
        self._video_codec = video_codec
        self._resolution = resolution
        self._fps = fps

    def setup(self):
        if self._fps != 30:
            self.skip_if_missing_capability(Capability.RECORD)
        self.skip_if_no_moving_picture()
        self.moving_picture_on()
        self.moblin.import_settings(
            overrides={
                "streams": [
                    {
                        "enabled": True,
                        "fps": self._fps,
                        "resolution": self._resolution,
                        "recording": {"videoCodec": self._video_codec},
                    }
                ],
                "scenes": [FRONT_SCENE_SETTINGS],
                "widgets": [],
            }
        )

    def run(self):
        time.sleep(1)
        recording_file = self.moblin.record(
            10, f"Record-{self._video_codec.name}-{self._resolution}@{self._fps}.mp4"
        )
        width, height = self._resolution.size()
        self.assert_recording(
            recording_file,
            has_qr_codes=False,
            width=width,
            height=height,
            fps=self._fps,
            video_codec=FFMPEG_VIDEO_CODECS[self._video_codec],
        )


def tests(moblin: Moblin):
    test_cases = [
        Record(
            moblin,
            video_codec=VideoCodec.H264,
            resolution=Resolution.FULL_HD,
            fps=30,
        ),
    ]
    for resolution in [Resolution.FULL_HD, Resolution.QUAD_HD, Resolution.ULTRA_HD]:
        for fps in [30, 60]:
            test_cases.append(
                Record(
                    moblin, video_codec=VideoCodec.H265, resolution=resolution, fps=fps
                )
            )
    return test_cases
