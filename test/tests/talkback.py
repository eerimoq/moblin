import logging
import time

from utils.config import RTMP_SERVER_PORT
from utils.ffmpeg import FfmpegAudioTestStream
from utils.moblin import Moblin
from utils.test_case import TestCase
from utils.utils import manual_validation

LOGGER = logging.getLogger(__name__)


class Talkback(TestCase):
    """Play talkback sound through the speaker for 10 seconds."""

    def run(self):
        stream = FfmpegAudioTestStream(
            url=f"rtmp://{self.moblin.ip_address}:{RTMP_SERVER_PORT}/live/talkback"
        )
        with stream:
            manual_validation(LOGGER, "Listen for periodic beeps")
            time.sleep(10)


def tests(moblin: Moblin):
    return [
        Talkback(moblin),
    ]
