from contextlib import contextmanager
from datetime import UTC
from datetime import datetime
from pathlib import Path

from systest_moblin.ffmpeg import FfmpegServer

from ..utils.config import TESTER_SRTLA_PORT
from ..utils.config import TESTER_SRTLA_SRT_PORT
from ..utils.config import WEB_REMOTE_CONTROL_PORT
from ..utils.config import Capability
from ..utils.config import rist_listener_url
from ..utils.config import srt_listener_url
from ..utils.generate_device_settings import AudioCodec
from ..utils.generate_device_settings import BitrateRateControl
from ..utils.generate_device_settings import CameraPosition
from ..utils.generate_device_settings import Resolution
from ..utils.generate_device_settings import SceneName
from ..utils.generate_device_settings import VideoCodec
from ..utils.generate_device_settings import mic_id
from ..utils.generate_device_settings import uuid
from ..utils.mediamtx import MediaMtx
from ..utils.moblin import Moblin
from ..utils.moblin import create_receiver
from ..utils.test_case import TestCase
from ..utils.utils import FILES_DIR
from ..utils.utils import Range
from ..utils.utils import format_generic_stream_url_stream_name

SRTLA_INGEST_ID = uuid()
SRTLA_STREAM_ID = "1"


class StreamTestCase(TestCase):
    def import_stream_settings(self, **stream):
        self.moblin.import_settings(
            overrides={
                "streams": [
                    {
                        "enabled": True,
                        "bitrateRateControl": BitrateRateControl.CBR,
                        **stream,
                    }
                ],
            }
        )

    def stream_to_ffmpeg(
        self,
        url: str,
        minimum_bitrate: int,
        maximum_bitrate: int,
        total_bytes: int,
    ) -> Path:
        filename = FILES_DIR / f"{self.name}.ts"
        self.moblin.set_scene(SceneName.FRONT)
        with FfmpegServer(url=url, filename=filename):
            self.moblin.go_live()
            self.moblin.wait_for_bitrate(minimum_bitrate, maximum_bitrate, None, total_bytes)
            self.moblin.end()
        return filename

    @contextmanager
    def stream_to_mediamtx(
        self,
        minimum_bitrate: int,
        maximum_bitrate: int,
        total_bytes: int,
        multi_streaming: str | None = None,
    ):
        self.moblin.set_scene(SceneName.FRONT)
        with MediaMtx() as mediamtx:
            self.moblin.go_live()
            self.moblin.wait_for_bitrate(minimum_bitrate, maximum_bitrate, multi_streaming, total_bytes)
            yield mediamtx
            self.moblin.end()


class StreamRtmpToMediaMtx(StreamTestCase):
    """RTMP stream from Moblin to MediaMTX for a few seconds."""

    def setup(self):
        self.import_stream_settings(
            url=self.moblin.tester_rtmp_url("test"),
            rtmp={"adaptiveBitrateEnabled": False},
        )

    def run(self):
        with self.stream_to_mediamtx(4_500_000, 5_500_000, 10_000_000) as mediamtx:
            mediamtx.wait_for_rtmp_stream("test", 10_000_000)


class StreamSrtToMediaMtx(StreamTestCase):
    """SRT stream from Moblin to MediaMTX for a few seconds."""

    def setup(self):
        self.import_stream_settings(
            url=self.moblin.tester_srt_publish_url("test"),
            srt={"adaptiveBitrateEnabled": False},
            bitrate=50_000_000,
        )

    def run(self):
        with self.stream_to_mediamtx(49_000_000, 51_000_000, 100_000_000) as mediamtx:
            mediamtx.wait_for_srt_stream("test", 100_000_000)


class StreamSrtToFfmpeg(StreamTestCase):
    """SRT stream from Moblin to ffmpeg for a few seconds."""

    def __init__(self, moblin: Moblin, resolution: Resolution, fps: int):
        super().__init__(moblin, f"StreamSrtToFfmpeg-{resolution}@{fps}")
        self._resolution = resolution
        self._fps = fps

    def setup(self):
        if self._fps == 60:
            self.skip_if_missing_capability(Capability.PIP)
        self.import_stream_settings(
            url=self.moblin.tester_srt_publish_url("test"),
            srt={"adaptiveBitrateEnabled": False},
            bitrate=5_000_000,
            resolution=self._resolution,
            fps=self._fps,
        )

    def run(self):
        filename = self.stream_to_ffmpeg(srt_listener_url(), 4_000_000, 6_000_000, 10_000_000)
        width, height = self._resolution.size()
        self.assert_live_stream(filename, width=width, height=height, fps=self._fps)


class StreamSrtToFfmpegHighBitrate(StreamTestCase):
    """SRT stream from Moblin to ffmpeg at 50 Mbps for a few seconds."""

    def setup(self):
        self.import_stream_settings(
            url=self.moblin.tester_srt_publish_url("test"),
            srt={"adaptiveBitrateEnabled": False},
            bitrate=50_000_000,
        )

    def run(self):
        filename = self.stream_to_ffmpeg(srt_listener_url(), 49_000_000, 51_000_000, 50_000_000)
        self.assert_live_stream(filename, minimum_length=1, maximum_length=10)


class StreamSrtToFfmpegEncrypted(StreamTestCase):
    """Encrypted SRT stream from Moblin to ffmpeg for a few seconds."""

    PASSPHRASE = "1234567890"

    def setup(self):
        self.import_stream_settings(
            url=self.moblin.tester_srt_publish_url("test", self.PASSPHRASE),
            srt={"adaptiveBitrateEnabled": False, "implementation": "Official"},
            bitrate=5_000_000,
        )

    def run(self):
        filename = self.stream_to_ffmpeg(
            srt_listener_url(passphrase=self.PASSPHRASE),
            4_000_000,
            6_000_000,
            10_000_000,
        )
        self.assert_live_stream(filename)


class StreamSrtToFfmpegTimecodes(StreamTestCase):
    """SRT stream with SEI timecodes from Moblin to ffmpeg for a few seconds."""

    def setup(self):
        self.import_stream_settings(
            url=self.moblin.tester_srt_publish_url("test"),
            srt={"adaptiveBitrateEnabled": False},
            codec=VideoCodec.H265,
            bitrate=5_000_000,
            timecodesEnabled=True,
            ntpPoolAddress="time.apple.com",
        )

    def run(self):
        started = datetime.now(UTC)
        filename = self.stream_to_ffmpeg(srt_listener_url(), 4_000_000, 6_000_000, 10_000_000)
        self.assert_live_stream(filename)
        self.assert_timecodes(filename, started, datetime.now(UTC))


class StreamSrtToFfmpegVideoRateControl(StreamTestCase):
    """SRT stream from Moblin to ffmpeg for a few seconds using given video rate control."""

    def __init__(self, moblin: Moblin, rate_control: BitrateRateControl):
        super().__init__(moblin, f"StreamSrtToFfmpegVideoRateControl{rate_control.title()}")
        self._rate_control = rate_control

    def setup(self):
        if self._rate_control != BitrateRateControl.CBR:
            self.skip_if_no_moving_picture()
            self.moving_picture_on()
        self.import_stream_settings(
            bitrateRateControl=self._rate_control,
            url=self.moblin.tester_srt_publish_url("test"),
            bitrate=5_000_000,
        )

    def run(self):
        filename = self.stream_to_ffmpeg(srt_listener_url(), 4_000_000, 6_000_000, 5_000_000)
        self.assert_live_stream(filename)


class StreamRistToFfmpeg(StreamTestCase):
    """RIST stream from Moblin to ffmpeg for a few seconds."""

    def setup(self):
        self.import_stream_settings(
            url=self.moblin.tester_rist_url(),
            rist={"adaptiveBitrateEnabled": False, "bonding": False},
            bitrate=5_000_000,
        )

    def run(self):
        filename = self.stream_to_ffmpeg(rist_listener_url(), 4_000_000, 6_000_000, 10_000_000)
        self.assert_live_stream(filename)


class StreamSrtlaBondingToMoblin(StreamTestCase):
    """SRTLA stream from Moblin over two network interfaces to Moblin on the tester machine."""

    def setup(self):
        self.skip_if_no_secondary_ip_address()
        self.skip_if_no_receiver()
        self.moblin.wait_for_tcp_ports(
            WEB_REMOTE_CONTROL_PORT,
            ip_address=self.moblin.secondary_ip_address,
        )
        self.import_stream_settings(
            url=self.moblin.tester_srtla_url(SRTLA_STREAM_ID),
            srt={"adaptiveBitrateEnabled": False},
            bitrate=5_000_000,
        )

    def run(self):
        with create_receiver(self.moblin.config) as receiver:
            receiver.import_settings(
                overrides={
                    "scenes": [
                        {
                            "cameraPosition": CameraPosition.SRTLA,
                            "srtlaCameraId": SRTLA_INGEST_ID,
                            "micId": mic_id(SRTLA_INGEST_ID),
                            "overrideMic": True,
                            "enabled": True,
                        }
                    ],
                    "srtlaServer": {
                        "enabled": True,
                        "srtPort": TESTER_SRTLA_SRT_PORT,
                        "srtlaPort": TESTER_SRTLA_PORT,
                        "streams": [
                            {
                                "id": SRTLA_INGEST_ID,
                                "name": "Test",
                                "streamId": SRTLA_STREAM_ID,
                            }
                        ],
                    },
                }
            )
            self.moblin.go_live()
            self.moblin.wait_for_bonding_connections(2)
            self.moblin.wait_for_bitrate(4_000_000, 6_000_000, None, 10_000_000)
            receiver.wait_for_ingests(
                bitrate=Range(4_000_000, 6_000_000),
                total_bytes=10_000_000,
                number_of_ingests=1,
            )
            self.moblin.end()


class StreamWhipToMediaMtx(StreamTestCase):
    """WHIP stream from Moblin to MediaMTX for a few seconds."""

    def setup(self):
        self.import_stream_settings(
            url=self.moblin.tester_whip_url("test"),
            codec=VideoCodec.H264,
            audioCodec=AudioCodec.OPUS,
            bitrate=5_000_000,
        )

    def run(self):
        with self.stream_to_mediamtx(4_500_000, 5_500_000, 10_000_000) as mediamtx:
            mediamtx.wait_for_webrtc_stream("test", 5_000_000)


class StreamMultiRtmpToMediaMtx(StreamTestCase):
    """Multiple RTMP streams from Moblin to MediaMTX for a few seconds."""

    def setup(self):
        moblin = self.moblin
        self.import_stream_settings(
            url=moblin.tester_rtmp_url("test1"),
            rtmp={"adaptiveBitrateEnabled": False},
            multiStreaming={
                "destinations": [
                    {
                        "name": "Test 2",
                        "url": moblin.tester_rtmp_url("test2"),
                        "enabled": True,
                    },
                    {
                        "name": "Test 3",
                        "url": moblin.tester_rtmp_url("test3"),
                        "enabled": True,
                    },
                ]
            },
        )

    def run(self):
        with self.stream_to_mediamtx(4_500_000, 5_500_000, 30_000_000, multi_streaming="x3") as mediamtx:
            mediamtx.wait_for_rtmp_stream("test1", 10_000_000)
            mediamtx.wait_for_rtmp_stream("test2", 10_000_000)
            mediamtx.wait_for_rtmp_stream("test3", 10_000_000)


class StreamToGenericUrls(StreamTestCase):
    """Stream to each generic URL for a few seconds."""

    def __init__(self, moblin: Moblin, number: int, generic_stream_url: str):
        self._generic_stream = format_generic_stream_url_stream_name(number, generic_stream_url)
        super().__init__(moblin, f"StreamToGenericUrls({self._generic_stream})")
        self._generic_stream_url = generic_stream_url

    def setup(self):
        self.import_stream_settings(
            url=self._generic_stream_url,
            codec=VideoCodec.H264,
            bitrate=5_000_000,
        )

    def run(self):
        self.moblin.set_scene(SceneName.FRONT)
        self.moblin.go_live()
        self.moblin.wait_for_bitrate(4_000_000, 6_000_000, None, 10_000_000)
        self.moblin.end()


def tests(moblin: Moblin):
    return [
        StreamRtmpToMediaMtx(moblin),
        StreamSrtToMediaMtx(moblin),
        StreamSrtToFfmpeg(moblin, resolution=Resolution.FULL_HD, fps=30),
        StreamSrtToFfmpeg(moblin, resolution=Resolution.FULL_HD, fps=60),
        StreamSrtToFfmpeg(moblin, resolution=Resolution.QUAD_HD_4_3, fps=30),
        StreamSrtToFfmpegHighBitrate(moblin),
        StreamSrtToFfmpegEncrypted(moblin),
        StreamSrtToFfmpegTimecodes(moblin),
        StreamSrtToFfmpegVideoRateControl(moblin, BitrateRateControl.ABR),
        StreamSrtToFfmpegVideoRateControl(moblin, BitrateRateControl.CBR),
        StreamSrtToFfmpegVideoRateControl(moblin, BitrateRateControl.VBR),
        StreamRistToFfmpeg(moblin),
        StreamSrtlaBondingToMoblin(moblin),
        StreamWhipToMediaMtx(moblin),
        StreamMultiRtmpToMediaMtx(moblin),
    ] + [
        StreamToGenericUrls(moblin, number, generic_stream_url)
        for number, generic_stream_url in enumerate(moblin.config.generic_stream_urls(), 1)
    ]
