import logging
from pathlib import Path
import time
from typing import List

from utils.ffmpeg import create_qr_codes_video
from utils.ffmpeg import QrCode
from utils.ffmpeg import read_qr_codes
from utils.utils import WEBSITES_ROOT
from utils.utils import Crop
from utils.utils import create_qr_code_image
from utils.web_server import WebServer
from utils.moblin import Moblin
from utils.test_case import TestCase

LOGGER = logging.getLogger(__name__)


class BrowserWidgetHighFpsVideo(TestCase):
    """Play a 30 FPS video for a few seconds. A QR code image should only be
    visible when the video is playing. Each frame in the video has a unique QR
    code.

    """

    def run(self):
        create_qr_code_image(
            "n 1 pts 999.0", WEBSITES_ROOT / "BrowserWidgetHighFpsVideo.jpg"
        )
        create_qr_codes_video(WEBSITES_ROOT / "BrowserWidgetHighFpsVideo.mp4")
        with WebServer(WEBSITES_ROOT):
            self.moblin.set_scene("Browser widget")
            time.sleep(2)
            self.moblin.start_recording()
            time.sleep(16)
            self.moblin.stop_recording()
            recording_file = self.moblin.download_and_delete_latest_recording(
                "BrowserWidgetHighFpsVideo.mp4"
            )
            self.assert_image_qr_codes(recording_file)
            self.assert_video_qr_codes(recording_file)

    def assert_image_qr_codes(self, recording_file: Path):
        crop = Crop(x=0, y=0, width=400, height=400)
        qr_codes = read_qr_codes(recording_file, crop)
        self.assert_no_qr_codes_found(qr_codes[:100])
        for qr_code in qr_codes[150:380]:
            self.assert_not_equal(qr_code.number, -1)
        self.assert_no_qr_codes_found(qr_codes[450:])

    def assert_video_qr_codes(self, recording_file: Path):
        crop = Crop(x=400, y=0, width=400, height=400)
        qr_codes = read_qr_codes(recording_file, crop)
        self.assert_no_qr_codes_found(qr_codes[:100])
        previous_frame_number = qr_codes[149].number
        seen_frame_number_count = 1
        for qr_code in qr_codes[150:380]:
            if qr_code.number == previous_frame_number:
                seen_frame_number_count += 1
            else:
                seen_frame_number_count = 1
            self.assert_greater_equal(qr_code.number, previous_frame_number)
            self.assert_less(seen_frame_number_count, 4)
            previous_frame_number = qr_code.number
        self.assert_no_qr_codes_found(qr_codes[450:])

    def assert_no_qr_codes_found(self, qr_codes: List[QrCode]):
        for qr_code in qr_codes:
            self.assert_equal(qr_code.number, -1)


class BrowserWidgetScriptDefer(TestCase):
    """Webpage with <script src="" defer> should show up."""

    def run(self):
        pass


def tests(moblin: Moblin):
    return [
        BrowserWidgetHighFpsVideo(moblin),
        BrowserWidgetScriptDefer(moblin),
    ]
