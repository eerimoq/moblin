import logging
import time

from utils.utils import manual_validation
from utils.moblin import Moblin
from utils.ffmpeg import FfmpegAudioTestStream
from utils.test_case import TestCase

LOGGER = logging.getLogger(__name__)


class Talkback(TestCase):
    """Play talkback sound through the speaker for 10 seconds."""

    def run(self):
        stream = FfmpegAudioTestStream(
            url=f"rtmp://{self.moblin.ip_address}:11935/live/talkback"
        )
        with stream:
            manual_validation(LOGGER, "Listen for periodic beeps")
            time.sleep(10)


def tests(moblin: Moblin):
    return [
        Talkback(moblin),
    ]
