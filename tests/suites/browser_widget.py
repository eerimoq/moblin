from pathlib import Path

from ..utils.config import WEB_SERVER_PORT
from ..utils.ffmpeg import Crop
from ..utils.ffmpeg import QrCode
from ..utils.ffmpeg import create_qr_codes_video
from ..utils.ffmpeg import read_qr_codes
from ..utils.generate_device_settings import RECORD_STREAM_SETTINGS
from ..utils.generate_device_settings import BrowserMode
from ..utils.generate_device_settings import CameraPosition
from ..utils.generate_device_settings import browser_widget_settings
from ..utils.generate_device_settings import scene_widget_settings
from ..utils.generate_device_settings import uuid
from ..utils.moblin import Moblin
from ..utils.test_case import TestCase
from ..utils.utils import WEBSITES_DIR
from ..utils.utils import create_qr_code_image
from ..utils.web_server import WebServer

PERIODIC_AUDIO_AND_VIDEO_WIDGET_ID = uuid()
AUDIO_AND_VIDEO_ONLY_WIDGET_ID = uuid()
AUDIO_ONLY_WIDGET_ID = uuid()
LOCAL_ONLY_WIDGET_ID = uuid()


class BrowserWidgetModes(TestCase):
    """4 browser widgets; one for each mode and one local only."""

    def import_settings(self):
        url = (
            f"http://{self.moblin.config.tester_ip_address()}:{WEB_SERVER_PORT}"
            "/BrowserWidgetHighFpsVideo.html"
        )
        self.moblin.import_settings(
            overrides={
                "streams": [RECORD_STREAM_SETTINGS],
                "scenes": [
                    {
                        "cameraPosition": CameraPosition.NONE,
                        "widgets": [
                            scene_widget_settings(PERIODIC_AUDIO_AND_VIDEO_WIDGET_ID, 0, 0, 100),
                            scene_widget_settings(AUDIO_AND_VIDEO_ONLY_WIDGET_ID, 50, 0, 100),
                            scene_widget_settings(AUDIO_ONLY_WIDGET_ID, 0, 50, 100),
                            scene_widget_settings(LOCAL_ONLY_WIDGET_ID, 50, 50, 100),
                        ],
                        "enabled": True,
                    }
                ],
                "widgets": [
                    browser_widget_settings(
                        "Browser periodic audio and video",
                        PERIODIC_AUDIO_AND_VIDEO_WIDGET_ID,
                        url,
                        mode=BrowserMode.PERIODIC_AUDIO_AND_VIDEO,
                    ),
                    browser_widget_settings(
                        "Browser audio and video only",
                        AUDIO_AND_VIDEO_ONLY_WIDGET_ID,
                        url,
                        mode=BrowserMode.AUDIO_AND_VIDEO_ONLY,
                    ),
                    browser_widget_settings(
                        "Browser audio only",
                        AUDIO_ONLY_WIDGET_ID,
                        url,
                        mode=BrowserMode.AUDIO_ONLY,
                    ),
                    browser_widget_settings(
                        "Browser local only",
                        LOCAL_ONLY_WIDGET_ID,
                        url,
                        localOnly=True,
                    ),
                ],
            }
        )

    def run(self):
        create_qr_code_image("n 1 pts 999.0", WEBSITES_DIR / "BrowserWidgetHighFpsVideo.jpg")
        create_qr_codes_video(WEBSITES_DIR / "BrowserWidgetHighFpsVideo.mp4")
        with WebServer(WEBSITES_DIR):
            self.import_settings()
            recording_file = self.moblin.record(16, "BrowserWidgetHighFpsVideo.mp4")
            self.assert_image_qr_codes_periodic_audio_and_video(recording_file)
            self.assert_video_qr_codes_periodic_audio_and_video(recording_file)
            self.assert_image_qr_codes_audio_and_video_only(recording_file)
            self.assert_video_qr_codes_audio_and_video_only(recording_file)
            self.assert_image_qr_codes_audio_only(recording_file)
            self.assert_video_qr_codes_audio_only(recording_file)
            self.assert_image_qr_codes_local_only(recording_file)
            self.assert_video_qr_codes_local_only(recording_file)

    def assert_image_qr_codes_periodic_audio_and_video(self, recording_file: Path):
        crop = Crop(x=0, y=0, width=400, height=400)
        qr_codes = read_qr_codes(recording_file, crop)
        self.assert_qr_codes_found(qr_codes)

    def assert_video_qr_codes_periodic_audio_and_video(self, recording_file: Path):
        crop = Crop(x=400, y=0, width=400, height=400)
        qr_codes = read_qr_codes(recording_file, crop)
        self.assert_high_fps_qr_codes_found(qr_codes[149:380])

    def assert_image_qr_codes_audio_and_video_only(self, recording_file: Path):
        crop = Crop(x=960, y=0, width=400, height=400)
        qr_codes = read_qr_codes(recording_file, crop)
        self.assert_no_qr_codes_found(qr_codes[:100])
        self.assert_qr_codes_found(qr_codes[150:380])
        self.assert_no_qr_codes_found(qr_codes[450:])

    def assert_video_qr_codes_audio_and_video_only(self, recording_file: Path):
        crop = Crop(x=960 + 400, y=0, width=400, height=400)
        qr_codes = read_qr_codes(recording_file, crop)
        self.assert_no_qr_codes_found(qr_codes[:100])
        self.assert_high_fps_qr_codes_found(qr_codes[149:380])
        self.assert_no_qr_codes_found(qr_codes[450:])

    def assert_image_qr_codes_audio_only(self, recording_file: Path):
        crop = Crop(x=0, y=540, width=400, height=400)
        qr_codes = read_qr_codes(recording_file, crop)
        self.assert_no_qr_codes_found(qr_codes)

    def assert_video_qr_codes_audio_only(self, recording_file: Path):
        crop = Crop(x=400, y=540, width=400, height=400)
        qr_codes = read_qr_codes(recording_file, crop)
        self.assert_no_qr_codes_found(qr_codes)

    def assert_image_qr_codes_local_only(self, recording_file: Path):
        crop = Crop(x=960, y=540, width=400, height=400)
        qr_codes = read_qr_codes(recording_file, crop)
        self.assert_no_qr_codes_found(qr_codes)

    def assert_video_qr_codes_local_only(self, recording_file: Path):
        crop = Crop(x=960 + 400, y=540, width=400, height=400)
        qr_codes = read_qr_codes(recording_file, crop)
        self.assert_no_qr_codes_found(qr_codes)

    def assert_qr_codes_found(self, qr_codes: list[QrCode]):
        for index, qr_code in enumerate(qr_codes):
            self.assert_not_equal(qr_code.number, -1, f"Index {index}")

    def assert_no_qr_codes_found(self, qr_codes: list[QrCode]):
        for index, qr_code in enumerate(qr_codes):
            self.assert_equal(qr_code.number, -1, f"Index {index}")

    def assert_high_fps_qr_codes_found(self, qr_codes: list[QrCode]):
        previous_frame_number = qr_codes[0].number
        seen_frame_number_count = 1
        for index, qr_code in enumerate(qr_codes[1:]):
            if qr_code.number == previous_frame_number:
                seen_frame_number_count += 1
            else:
                seen_frame_number_count = 1
            self.assert_greater_equal(qr_code.number, previous_frame_number, f"Index {index}")
            self.assert_less(seen_frame_number_count, 4, f"Index {index}")
            previous_frame_number = qr_code.number


def tests(moblin: Moblin):
    return [
        BrowserWidgetModes(moblin),
    ]
