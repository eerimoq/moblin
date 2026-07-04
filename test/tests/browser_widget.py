import logging
import time

from utils.ffmpeg import create_qr_codes_video
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
            image_crop = Crop(x=0, y=0, width=400, height=400)
            image_qr_codes = read_qr_codes(recording_file, image_crop)
            for qr_code in image_qr_codes[:100]:
                self.assert_equal(qr_code.number, -1)
            for qr_code in image_qr_codes[150:380]:
                self.assert_not_equal(qr_code.number, -1)
            for qr_code in image_qr_codes[450:]:
                self.assert_equal(qr_code.number, -1)
            video_crop = Crop(x=400, y=0, width=400, height=400)
            video_qr_codes = read_qr_codes(recording_file, video_crop)
            for qr_code in video_qr_codes[:100]:
                self.assert_equal(qr_code.number, -1)
            previous_frame_number = video_qr_codes[149].number
            seen_frame_number_count = 1
            for qr_code in video_qr_codes[150:380]:
                if qr_code.number == previous_frame_number:
                    seen_frame_number_count += 1
                else:
                    seen_frame_number_count = 1
                self.assert_greater_equal(qr_code.number, previous_frame_number)
                self.assert_less(seen_frame_number_count, 4)
                previous_frame_number = qr_code.number
            for qr_code in video_qr_codes[450:]:
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
