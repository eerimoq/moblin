import logging
import time

from utils.config import RTMP_SERVER_PORT
from utils.config import SRT_CLIENT_TALKBACK_SERVER_PORT
from utils.config import SRT_SERVER_PORT
from utils.config import srt_listener_url
from utils.ffmpeg import FfmpegAudioTestStream
from utils.ffmpeg import TransportFormat
from utils.generate_device_settings import mic_id
from utils.generate_device_settings import uuid
from utils.moblin import Moblin
from utils.test_case import TestCase
from utils.utils import manual_validation

LOGGER = logging.getLogger(__name__)
RTMP_TALKBACK_STREAM_ID = uuid()
SRT_TALKBACK_STREAM_ID = uuid()
SRT_CLIENT_TALKBACK_STREAM_ID = uuid()


class TalkbackTestCase(TestCase):
    def import_settings(self, stream_id: str, **overrides):
        self.moblin.import_settings(
            overrides={
                "talkBack": {"enabled": True, "micId": mic_id(stream_id)},
                **overrides,
            }
        )
        time.sleep(1)

    def play_beeps(self, url: str, transport_format=TransportFormat.FLV):
        with FfmpegAudioTestStream(url=url, transport_format=transport_format):
            manual_validation(LOGGER, "Listen for periodic beeps")
            time.sleep(10)


class TalkbackRtmpServer(TalkbackTestCase):
    """Play talkback sound over RTMP server through the speaker for 10 seconds."""

    def setup(self):
        self.import_settings(
            RTMP_TALKBACK_STREAM_ID,
            rtmpServer={
                "enabled": True,
                "port": RTMP_SERVER_PORT,
                "streams": [
                    {
                        "id": RTMP_TALKBACK_STREAM_ID,
                        "name": "Talkback",
                        "streamKey": "talkback",
                    }
                ],
            },
        )

    def run(self):
        self.play_beeps(self.moblin.ingest_rtmp_url("talkback"))


class TalkbackSrtlaServer(TalkbackTestCase):
    """Play talkback sound over SRTLA server through the speaker for 10 seconds."""

    def setup(self):
        self.import_settings(
            SRT_TALKBACK_STREAM_ID,
            srtlaServer={
                "enabled": True,
                "srtPort": SRT_SERVER_PORT,
                "streams": [
                    {
                        "id": SRT_TALKBACK_STREAM_ID,
                        "name": "Talkback",
                        "streamId": "talkback",
                    }
                ],
            },
        )

    def run(self):
        self.play_beeps(self.moblin.ingest_srt_url("talkback"), TransportFormat.MPEGTS)


class TalkbackSrtClient(TalkbackTestCase):
    """Play talkback sound over SRT client through the speaker for 10 seconds."""

    def setup(self):
        self.import_settings(
            SRT_CLIENT_TALKBACK_STREAM_ID,
            srtClient={
                "streams": [
                    {
                        "id": SRT_CLIENT_TALKBACK_STREAM_ID,
                        "name": "Talkback",
                        "url": self.moblin.tester_srt_url(
                            SRT_CLIENT_TALKBACK_SERVER_PORT
                        ),
                        "enabled": True,
                    }
                ],
            },
        )

    def run(self):
        self.play_beeps(
            srt_listener_url(SRT_CLIENT_TALKBACK_SERVER_PORT), TransportFormat.MPEGTS
        )


def tests(moblin: Moblin):
    return [
        TalkbackRtmpServer(moblin),
        TalkbackSrtlaServer(moblin),
        TalkbackSrtClient(moblin),
    ]
