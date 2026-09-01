import logging
from pathlib import Path

from systest_moblin.ffmpeg import FfmpegVideoCodec
from systest_moblin.ffmpeg import ffprobe
from systest_moblin.ffmpeg import measure_mean_volume
from systest_moblin.ffmpeg import read_video_frame

from ..utils.config import RTMP_SERVER_PORT
from ..utils.generate_device_settings import RECORD_STREAM_SETTINGS
from ..utils.generate_device_settings import CameraPosition
from ..utils.generate_device_settings import dji_device_settings
from ..utils.generate_device_settings import mic_id
from ..utils.generate_device_settings import uuid
from ..utils.moblin import Moblin
from ..utils.test_case import TestCase

LOGGER = logging.getLogger(__name__)
STREAM_ID = uuid()


class DjiCameraRtmpServer(TestCase):
    """Record 10 seconds of video and audio from a DJI camera streaming to the RTMP server."""

    def setup(self):
        self.skip_if_no_dji_camera()
        self.moblin.import_settings(
            overrides={
                "streams": [RECORD_STREAM_SETTINGS],
                "scenes": [
                    {
                        "cameraPosition": CameraPosition.RTMP,
                        "rtmpCameraId": STREAM_ID,
                        "micId": mic_id(STREAM_ID),
                        "enabled": True,
                        "overrideMic": True,
                    }
                ],
                "rtmpServer": {
                    "enabled": True,
                    "port": RTMP_SERVER_PORT,
                    "streams": [{"id": STREAM_ID, "name": "DJI", "streamKey": "dji"}],
                },
                "djiDevices": {"devices": [dji_device_settings(STREAM_ID, self.moblin.config.dji_camera())]},
            }
        )

    def run(self):
        self.moblin.wait_for_dji_devices_streaming()
        self.wait_for_ingest_stream_started()
        recording = self.moblin.record(10, f"{self.name}.mp4")
        self.assert_dji_camera_recording(recording)

    def assert_dji_camera_recording(self, recording: Path):
        metadata = ffprobe(recording)
        self.assert_greater(metadata.format.duration, 8)
        self.assert_less(metadata.format.duration, 14)
        self.assert_equal(metadata.video.codec, FfmpegVideoCodec.HEVC)
        self.assert_equal(metadata.video.width, 1920)
        self.assert_equal(metadata.video.height, 1080)
        self.assert_fps(metadata.video.average_fps, 30)
        self.assert_presentation_time_stamps(
            recording,
            1 / 30,
            [frame.pts for frame in metadata.video.frames],
            "video",
        )
        self.assert_not_all_black(read_video_frame(recording, 5))
        self.assert_equal(metadata.audio.codec, "aac")
        self.assert_equal(metadata.audio.sample_rate, 48000)
        self.assert_presentation_time_stamps(
            recording,
            1024 / 48000,
            [frame.pts for frame in metadata.audio.frames],
            "audio",
        )
        mean_volume_db = measure_mean_volume(recording)
        LOGGER.debug("Mean volume: %.1f dB", mean_volume_db)
        self.assert_greater(
            mean_volume_db,
            -70,
            "No audio was picked up by the microphone of the DJI camera.",
        )


def tests(moblin: Moblin):
    return [DjiCameraRtmpServer(moblin)]
