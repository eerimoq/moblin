import logging
import time
from pathlib import Path
from typing import List

from utils.ffmpeg import QrCode
from utils.ffmpeg import create_qr_codes_video
from utils.ffmpeg import read_qr_codes
from utils.moblin import Moblin
from utils.test_case import TestCase
from utils.utils import WEBSITES_ROOT
from utils.utils import Crop
from utils.utils import create_qr_code_image
from utils.web_server import WebServer

LOGGER = logging.getLogger(__name__)


class BrowserWidgetModes(TestCase):
    """4 browser widgets; one for each mode and one local only."""

    def run(self):
        create_qr_code_image(
            "n 1 pts 999.0", WEBSITES_ROOT / "BrowserWidgetHighFpsVideo.jpg"
        )
        create_qr_codes_video(WEBSITES_ROOT / "BrowserWidgetHighFpsVideo.mp4")
        with WebServer(WEBSITES_ROOT):
            self.moblin.set_scene("Browser widgets")
            time.sleep(2)
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
        self.assert_qr_codes_found(qr_codes[:100])
        self.assert_high_fps_qr_codes_found(qr_codes[149:380])
        self.assert_qr_codes_found(qr_codes[450:])

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

    def assert_qr_codes_found(self, qr_codes: List[QrCode]):
        for qr_code in qr_codes:
            self.assert_not_equal(qr_code.number, -1)

    def assert_no_qr_codes_found(self, qr_codes: List[QrCode]):
        for qr_code in qr_codes:
            self.assert_equal(qr_code.number, -1)

    def assert_high_fps_qr_codes_found(self, qr_codes: List[QrCode]):
        previous_frame_number = qr_codes[0].number
        seen_frame_number_count = 1
        for qr_code in qr_codes[1:]:
            if qr_code.number == previous_frame_number:
                seen_frame_number_count += 1
            else:
                seen_frame_number_count = 1
            self.assert_greater_equal(qr_code.number, previous_frame_number)
            self.assert_less(seen_frame_number_count, 4)
            previous_frame_number = qr_code.number


def tests(moblin: Moblin):
    return [
        BrowserWidgetModes(moblin),
    ]
