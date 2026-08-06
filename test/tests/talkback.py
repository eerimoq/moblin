import logging
import time

from utils.config import RTMP_SERVER_PORT
from utils.config import SRT_CLIENT_TALKBACK_SERVER_PORT
from utils.config import SRT_SERVER_PORT
from utils.ffmpeg import FfmpegAudioTestStream
from utils.generate_device_settings import FRONT_SCENE_SETTINGS
from utils.moblin import Moblin
from utils.test_case import TestCase
from utils.utils import manual_validation

LOGGER = logging.getLogger(__name__)
RTMP_TALKBACK_STREAM_ID = "F3868489-D301-422D-A7DD-335572CA1386"
SRT_TALKBACK_STREAM_ID = "F3868489-D301-422D-A7DD-135572CA1389"
SRT_CLIENT_TALKBACK_STREAM_ID = "F3868489-D301-522D-A7DD-135572CA1389"


class TalkbackRtmpServer(TestCase):
    """Play talkback sound over RTMP server through the speaker for 10 seconds."""

    def setup(self):
        self.moblin.import_settings(
            overrides={
                "scenes": [FRONT_SCENE_SETTINGS],
                "widgets": [],
                "rtmpServer": {
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
                "talkBack": {
                    "enabled": True,
                    "micId": f"{RTMP_TALKBACK_STREAM_ID} 0",
                },
            }
        )
        time.sleep(1)

    def run(self):
        stream = FfmpegAudioTestStream(
            url=f"rtmp://{self.moblin.ip_address}:{RTMP_SERVER_PORT}/live/talkback"
        )
        with stream:
            manual_validation(LOGGER, "Listen for periodic beeps")
            time.sleep(10)


class TalkbackSrtlaServer(TestCase):
    """Play talkback sound over SRTLA server through the speaker for 10 seconds."""

    def setup(self):
        self.moblin.import_settings(
            overrides={
                "scenes": [FRONT_SCENE_SETTINGS],
                "widgets": [],
                "srtlaServer": {
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
                "talkBack": {
                    "enabled": True,
                    "micId": f"{SRT_TALKBACK_STREAM_ID} 0",
                },
            }
        )
        time.sleep(1)

    def run(self):
        stream = FfmpegAudioTestStream(
            url=f"srt://{self.moblin.ip_address}:{SRT_SERVER_PORT}?streamid=talkback",
            transport_format="mpegts",
        )
        with stream:
            manual_validation(LOGGER, "Listen for periodic beeps")
            time.sleep(10)


class TalkbackSrtClient(TestCase):
    """Play talkback sound over SRT client through the speaker for 10 seconds."""

    def setup(self):
        url = (
            f"srt://{self.moblin.config.tester_ip_address()}"
            f":{SRT_CLIENT_TALKBACK_SERVER_PORT}"
        )
        self.moblin.import_settings(
            overrides={
                "scenes": [FRONT_SCENE_SETTINGS],
                "widgets": [],
                "srtClient": {
                    "streams": [
                        {
                            "id": SRT_CLIENT_TALKBACK_STREAM_ID,
                            "name": "Talkback",
                            "url": url,
                            "enabled": True,
                        }
                    ],
                },
                "talkBack": {
                    "enabled": True,
                    "micId": f"{SRT_CLIENT_TALKBACK_STREAM_ID} 0",
                },
            }
        )
        time.sleep(1)

    def run(self):
        stream = FfmpegAudioTestStream(
            url=f"srt://0.0.0.0:{SRT_CLIENT_TALKBACK_SERVER_PORT}?mode=listener",
            transport_format="mpegts",
        )
        with stream:
            manual_validation(LOGGER, "Listen for periodic beeps")
            time.sleep(10)


def tests(moblin: Moblin):
    return [
        TalkbackRtmpServer(moblin),
        TalkbackSrtlaServer(moblin),
        TalkbackSrtClient(moblin),
    ]
