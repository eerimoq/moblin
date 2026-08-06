import logging
import time
from pathlib import Path

from utils.ffmpeg import QrCode
from utils.ffmpeg import create_qr_codes_video
from utils.ffmpeg import read_qr_codes
from utils.generate_device_settings import RECORD_STREAM_SETTINGS
from utils.generate_device_settings import scene_widget_settings
from utils.moblin import Moblin
from utils.test_case import TestCase
from utils.utils import WEBSITES_ROOT
from utils.utils import Crop
from utils.utils import create_qr_code_image
from utils.web_server import WebServer

LOGGER = logging.getLogger(__name__)
PERIODIC_AUDIO_AND_VIDEO_WIDGET_ID = "F3868489-D301-422D-A7DD-335572CA1312"
AUDIO_AND_VIDEO_ONLY_WIDGET_ID = "F3868489-D301-422D-A7DD-335572CA1313"
AUDIO_ONLY_WIDGET_ID = "F3868489-D301-422D-A7DD-335572CA1314"
LOCAL_ONLY_WIDGET_ID = "F3868489-D301-422D-A7DD-335572CA1315"


def widget_settings(widget_id: str, name: str, url: str, **browser):
    return {
        "id": widget_id,
        "name": name,
        "type": "Browser",
        "browser": {"url": url, "width": 1920, "height": 1080, **browser},
    }


class BrowserWidgetModes(TestCase):
    """4 browser widgets; one for each mode and one local only."""

    def import_settings(self):
        url = (
            f"http://{self.moblin.config.tester_ip_address()}:6967"
            "/BrowserWidgetHighFpsVideo.html"
        )
        self.moblin.import_settings(
            overrides={
                "streams": [RECORD_STREAM_SETTINGS],
                "scenes": [
                    {
                        "cameraPosition": "Screen capture",
                        "widgets": [
                            scene_widget_settings(
                                PERIODIC_AUDIO_AND_VIDEO_WIDGET_ID, 0, 0, 100
                            ),
                            scene_widget_settings(
                                AUDIO_AND_VIDEO_ONLY_WIDGET_ID, 50, 0, 100
                            ),
                            scene_widget_settings(AUDIO_ONLY_WIDGET_ID, 0, 50, 100),
                            scene_widget_settings(LOCAL_ONLY_WIDGET_ID, 50, 50, 100),
                        ],
                        "enabled": True,
                    }
                ],
                "widgets": [
                    widget_settings(
                        PERIODIC_AUDIO_AND_VIDEO_WIDGET_ID,
                        "Browser periodic audio and video",
                        url,
                        mode="periodicAudioAndVideo",
                    ),
                    widget_settings(
                        AUDIO_AND_VIDEO_ONLY_WIDGET_ID,
                        "Browser audio and video only",
                        url,
                        mode="audioAndVideoOnly",
                    ),
                    widget_settings(
                        AUDIO_ONLY_WIDGET_ID,
                        "Browser audio only",
                        url,
                        mode="audioOnly",
                    ),
                    widget_settings(
                        LOCAL_ONLY_WIDGET_ID,
                        "Browser local only",
                        url,
                        localOnly=True,
                    ),
                ],
            }
        )

    def run(self):
        create_qr_code_image(
            "n 1 pts 999.0", WEBSITES_ROOT / "BrowserWidgetHighFpsVideo.jpg"
        )
        create_qr_codes_video(WEBSITES_ROOT / "BrowserWidgetHighFpsVideo.mp4")
        with WebServer(WEBSITES_ROOT):
            self.import_settings()
            self.moblin.start_recording()
            time.sleep(16)
            self.moblin.stop_recording()
            recording_file = self.moblin.download_and_delete_latest_recording(
                "BrowserWidgetHighFpsVideo.mp4"
            )
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
            self.assert_greater_equal(
                qr_code.number, previous_frame_number, f"Index {index}"
            )
            self.assert_less(seen_frame_number_count, 4, f"Index {index}")
            previous_frame_number = qr_code.number


def tests(moblin: Moblin):
    return [
        BrowserWidgetModes(moblin),
    ]
