import logging
import time

from utils.config import RTMP_SERVER_PORT
from utils.config import SRT_CLIENT_TALKBACK_SERVER_PORT
from utils.config import SRT_SERVER_PORT
from utils.ffmpeg import FfmpegAudioTestStream
from utils.moblin import Moblin
from utils.test_case import TestCase
from utils.utils import manual_validation

LOGGER = logging.getLogger(__name__)


class TalkbackRtmpServer(TestCase):
    """Play talkback sound over RTMP server through the speaker for 10 seconds."""

    def run(self):
        stream = FfmpegAudioTestStream(
            url=f"rtmp://{self.moblin.ip_address}:{RTMP_SERVER_PORT}/live/talkback"
        )
        with stream:
            self.moblin.set_talkback_mic("Talkback (RTMP)")
            manual_validation(LOGGER, "Listen for periodic beeps")
            time.sleep(10)


class TalkbackSrtlaServer(TestCase):
    """Play talkback sound over SRTLA server through the speaker for 10 seconds."""

    def run(self):
        stream = FfmpegAudioTestStream(
            url=f"srt://{self.moblin.ip_address}:{SRT_SERVER_PORT}?streamid=talkback",
            transport_format="mpegts",
        )
        with stream:
            self.moblin.set_talkback_mic("Talkback (SRT(LA))")
            manual_validation(LOGGER, "Listen for periodic beeps")
            time.sleep(10)


class TalkbackSrtClient(TestCase):
    """Play talkback sound over SRT client through the speaker for 10 seconds."""

    def run(self):
        stream = FfmpegAudioTestStream(
            url=f"srt://0.0.0.0:{SRT_CLIENT_TALKBACK_SERVER_PORT}?mode=listener",
            transport_format="mpegts",
        )
        with stream:
            self.moblin.set_talkback_mic("Talkback (SRT client)")
            manual_validation(LOGGER, "Listen for periodic beeps")
            time.sleep(10)


def tests(moblin: Moblin):
    return [
        TalkbackRtmpServer(moblin),
        TalkbackSrtlaServer(moblin),
        TalkbackSrtClient(moblin),
    ]
