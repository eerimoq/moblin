import time

from ..utils.common.ffmpeg import FfmpegVideoCodec
from ..utils.config import Capability
from ..utils.generate_device_settings import Resolution
from ..utils.generate_device_settings import VideoCodec
from ..utils.moblin import Moblin
from ..utils.test_case import TestCase
from ..utils.utils import FILES_DIR

FFMPEG_VIDEO_CODECS = {
    VideoCodec.H264: FfmpegVideoCodec.H264,
    VideoCodec.H265: FfmpegVideoCodec.HEVC,
}


class Record(TestCase):
    """Record a 10 seconds video."""

    def __init__(self, moblin: Moblin, video_codec: VideoCodec, resolution: Resolution, fps: int):
        super().__init__(moblin, f"Record{video_codec.name}-{resolution}@{fps}")
        self._video_codec = video_codec
        self._resolution = resolution
        self._fps = fps

    def setup(self):
        if self._fps != 30:
            self.skip_if_missing_capability(Capability.RECORD)
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
            }
        )

    def run(self):
        time.sleep(1)
        recording_file = self.moblin.record(10, f"{self.name}.mp4")
        width, height = self._resolution.size()
        self.assert_recording(
            recording_file,
            FILES_DIR,
            has_qr_codes=False,
            duplicated_frames_crops=None if self.moblin.has_moving_picture() else [],
            width=width,
            height=height,
            fps=self._fps,
            video_codec=FFMPEG_VIDEO_CODECS[self._video_codec],
        )


def tests(moblin: Moblin):
    return [
        Record(moblin, VideoCodec.H264, Resolution.FULL_HD, 30),
        Record(moblin, VideoCodec.H265, Resolution.FULL_HD, 30),
        Record(moblin, VideoCodec.H265, Resolution.FULL_HD, 60),
        Record(moblin, VideoCodec.H265, Resolution.QUAD_HD_4_3, 30),
        Record(moblin, VideoCodec.H265, Resolution.QUAD_HD, 30),
        # Record(moblin, VideoCodec.H265, Resolution.QUAD_HD, 60),
        Record(moblin, VideoCodec.H265, Resolution.ULTRA_HD, 30),
        # Record(moblin, VideoCodec.H265, Resolution.ULTRA_HD, 60),
    ]
