import logging
from pathlib import Path
import subprocess
import time

from utils.ffmpeg import create_qr_codes_video
from utils.utils import WEBSITES_ROOT
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
        command = [
            "qrtool",
            "encode",
            "--output",
            str(WEBSITES_ROOT / "BrowserWidgetHighFpsVideo.jpg"),
            "BrowserWidgetHighFpsVideo",
        ]
        print(" ".join(command))
        subprocess.run(command, check=True)
        create_qr_codes_video(WEBSITES_ROOT / "BrowserWidgetHighFpsVideo.mp4")
        with WebServer(WEBSITES_ROOT):
            time.sleep(1)


class BrowserWidgetScriptDefer(TestCase):
    """Webpage with <script src="" defer> should show up."""

    def run(self):
        pass


def tests(moblin: Moblin):
    return [
        BrowserWidgetHighFpsVideo(moblin),
        BrowserWidgetScriptDefer(moblin),
    ]
