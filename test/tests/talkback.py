import logging
import time

import systest
from utils.utils import manual_validation
from utils.moblin import Moblin
from utils.ffmpeg import FfmpegAudioTestStream

LOGGER = logging.getLogger(__name__)


class Talkback(systest.TestCase):
    """Play talkback sound through the speaker for 10 seconds."""

    def __init__(self, moblin: Moblin):
        super().__init__()
        self.moblin = moblin

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
