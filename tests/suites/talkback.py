import logging
import time
from pathlib import Path

from systest_moblin.ffmpeg import BEEP_INTERVAL
from systest_moblin.ffmpeg import FfmpegAudioTestStream
from systest_moblin.ffmpeg import TransportFormat
from systest_moblin.ffmpeg import detect_beeps

from ..utils.config import RTMP_SERVER_PORT
from ..utils.config import SRT_CLIENT_TALKBACK_SERVER_PORT
from ..utils.config import SRT_SERVER_PORT
from ..utils.config import srt_listener_url
from ..utils.generate_device_settings import mic_id
from ..utils.generate_device_settings import uuid
from ..utils.moblin import Moblin
from ..utils.test_case import TestCase
from ..utils.utils import manual_validation
from ..utils.utils import manual_volume_requirement

LOGGER = logging.getLogger(__name__)
RTMP_TALKBACK_STREAM_ID = uuid()
SRT_TALKBACK_STREAM_ID = uuid()
SRT_CLIENT_TALKBACK_STREAM_ID = uuid()
RECORDING_DURATION = 10
MINIMUM_NUMBER_OF_BEEPS = 3


class TalkbackTestCase(TestCase):
    def import_settings(self, stream_id: str, **overrides):
        self.moblin.import_settings(
            overrides={
                "talkBack": {"enabled": True, "micId": mic_id(stream_id)},
                **overrides,
            }
        )
        time.sleep(1)

    def play_beeps(
        self,
        url: str,
        transport_format=TransportFormat.FLV,
        recording_duration=RECORDING_DURATION,
    ):
        manual_volume_requirement(LOGGER)
        with FfmpegAudioTestStream(url=url, transport_format=transport_format):
            time.sleep(BEEP_INTERVAL)
            recording = self.moblin.record(recording_duration, f"{self.name}.mp4")
        self.assert_beeps(recording)

    def assert_beeps(self, recording: Path):
        beeps = detect_beeps(recording)
        LOGGER.debug(
            "Found %s beeps in %s at %s.",
            len(beeps),
            recording,
            ", ".join(f"{beep:.3f} s" for beep in beeps),
        )
        self.assert_greater_equal(len(beeps), MINIMUM_NUMBER_OF_BEEPS)


class TalkbackRtmpServer(TalkbackTestCase):
    """Play talkback sound over RTMP server through the speaker and record the beeps."""

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
        self.moblin.wait_for_tcp_ports(RTMP_SERVER_PORT)

    def run(self):
        self.play_beeps(self.moblin.ingest_rtmp_url("talkback"))


class TalkbackSrtlaServer(TalkbackTestCase):
    """Play talkback sound over SRTLA server through the speaker and record the beeps."""

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
    """Play talkback sound over SRT client through the speaker and record the beeps."""

    def setup(self):
        self.import_settings(
            SRT_CLIENT_TALKBACK_STREAM_ID,
            srtClient={
                "streams": [
                    {
                        "id": SRT_CLIENT_TALKBACK_STREAM_ID,
                        "name": "Talkback",
                        "url": self.moblin.tester_srt_url(SRT_CLIENT_TALKBACK_SERVER_PORT),
                        "enabled": True,
                    }
                ],
            },
        )

    def run(self):
        self.play_beeps(
            srt_listener_url(SRT_CLIENT_TALKBACK_SERVER_PORT),
            TransportFormat.MPEGTS,
            RECORDING_DURATION + 5,
        )


class TalkbackChatPhone(TalkbackTestCase):
    """Play talkback sound over RTMP server through the speaker in chat phone mode."""

    def setup(self):
        self.import_settings(
            RTMP_TALKBACK_STREAM_ID,
            appMode="chatPhone",
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
        self.moblin.wait_for_tcp_ports(RTMP_SERVER_PORT)

    def run(self):
        manual_volume_requirement(LOGGER)
        with FfmpegAudioTestStream(url=self.moblin.ingest_rtmp_url("talkback")):
            time.sleep(10)
        manual_validation(LOGGER, "Beeps were heard from the speaker")


def tests(moblin: Moblin):
    return [
        TalkbackRtmpServer(moblin),
        TalkbackSrtlaServer(moblin),
        TalkbackSrtClient(moblin),
        TalkbackChatPhone(moblin),
    ]
