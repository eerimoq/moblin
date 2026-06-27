import logging
import time

import systest
from utils.moblin import Moblin
from utils.ffmpeg import FfmpegTestStream

LOGGER = logging.getLogger(__name__)


class Talkback(systest.TestCase):
    """Play talkback sound through the speaker for 10 seconds."""

    def __init__(self, moblin: Moblin):
        super().__init__()
        self.moblin = moblin

    def run(self):
        rtmp_stream = FfmpegTestStream(
            url=f"rtmp://{self.moblin.ip_address}:11935/live/talkback"
        )
        with rtmp_stream:
            time.sleep(10)
