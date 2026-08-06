import logging
from pathlib import Path

from utils.ffmpeg import FfmpegServer
from utils.mediamtx import MediaMtx
from utils.moblin import Moblin
from utils.test_case import TestCase
from utils.utils import format_generic_stream_url_stream_name

LOGGER = logging.getLogger(__name__)

FRONT_SCENE_SETTINGS = {"name": "Front", "cameraPosition": "Front", "enabled": True}


class StreamRtmpToMediaMtx(TestCase):
    """RTMP stream from Moblin to MediaMTX for a few seconds."""

    def setup(self):
        self.moblin.import_settings(
            overrides={
                "streams": [
                    {
                        "enabled": True,
                        "bitrateRateControl": "CBR",
                        "url": f"rtmp://{self.moblin.config.tester_ip_address()}:1935/test",
                        "rtmp": {"adaptiveBitrateEnabled": False},
                    }
                ],
                "scenes": [FRONT_SCENE_SETTINGS],
            }
        )

    def run(self):
        self.moblin.set_scene("Front")
        with MediaMtx() as mediamtx:
            self.moblin.go_live()
            self.moblin.wait_for_bitrate(4_500_000, 5_500_000, None, 10_000_000)
            mediamtx.wait_for_rtmp_stream("test", 10_000_000)
            self.moblin.end()


class StreamSrtToMediaMtx(TestCase):
    """SRT stream from Moblin to MediaMTX for a few seconds."""

    def setup(self):
        self.moblin.import_settings(
            overrides={
                "streams": [
                    {
                        "enabled": True,
                        "bitrateRateControl": "CBR",
                        "url": f"srt://{self.moblin.config.tester_ip_address()}:8890?streamid=publish:test",
                        "srt": {"adaptiveBitrateEnabled": False},
                        "bitrate": 50_000_000,
                    }
                ],
                "scenes": [FRONT_SCENE_SETTINGS],
            }
        )

    def run(self):
        self.moblin.set_scene("Front")
        with MediaMtx() as mediamtx:
            self.moblin.go_live()
            self.moblin.wait_for_bitrate(49_000_000, 51_000_000, None, 100_000_000)
            mediamtx.wait_for_srt_stream("test", 100_000_000)
            self.moblin.end()


class StreamSrtToFfmpeg(TestCase):
    """SRT stream from Moblin to ffmpeg for a few seconds."""

    def __init__(self, moblin: Moblin, fps: int):
        super().__init__(moblin, f"StreamSrtToFfmpeg{fps}Fps")
        self._fps = fps

    def setup(self):
        self.moblin.import_settings(
            overrides={
                "streams": [
                    {
                        "enabled": True,
                        "bitrateRateControl": "CBR",
                        "url": f"srt://{self.moblin.config.tester_ip_address()}:8890?streamid=publish:test",
                        "srt": {"adaptiveBitrateEnabled": False},
                        "bitrate": 5_000_000,
                        "fps": self._fps,
                    }
                ],
                "scenes": [FRONT_SCENE_SETTINGS],
            }
        )

    def run(self):
        filename = Path(f"files/{self.name}.ts")
        self.moblin.set_scene("Front")
        with FfmpegServer(url="srt://0.0.0.0:8890?mode=listener", filename=filename):
            self.moblin.go_live()
            self.moblin.wait_for_bitrate(4_000_000, 6_000_000, None, 10_000_000)
            self.moblin.end()
        self.assert_live_stream(filename)


class StreamSrtToFfmpegHighBitrate(TestCase):
    """SRT stream from Moblin to ffmpeg at 50 Mbps for a few seconds."""

    def setup(self):
        self.moblin.import_settings(
            overrides={
                "streams": [
                    {
                        "enabled": True,
                        "bitrateRateControl": "CBR",
                        "url": f"srt://{self.moblin.config.tester_ip_address()}:8890?streamid=publish:test",
                        "srt": {"adaptiveBitrateEnabled": False},
                        "bitrate": 50_000_000,
                    }
                ],
                "scenes": [FRONT_SCENE_SETTINGS],
            }
        )

    def run(self):
        filename = Path("files/StreamSrtFromMoblinToFfmpegHighBitrate.ts")
        self.moblin.set_scene("Front")
        with FfmpegServer(url="srt://0.0.0.0:8890?mode=listener", filename=filename):
            self.moblin.go_live()
            self.moblin.wait_for_bitrate(49_000_000, 51_000_000, None, 50_000_000)
            self.moblin.end()
        self.assert_live_stream(filename, minimum_length=1, maximum_length=10)


class StreamSrtToFfmpegEncrypted(TestCase):
    """Encrypted SRT stream from Moblin to ffmpeg for a few seconds."""

    def setup(self):
        url = (
            f"srt://{self.moblin.config.tester_ip_address()}:8890"
            "?streamid=publish:test&passphrase=1234567890"
        )
        self.moblin.import_settings(
            overrides={
                "streams": [
                    {
                        "enabled": True,
                        "bitrateRateControl": "CBR",
                        "url": url,
                        "srt": {
                            "adaptiveBitrateEnabled": False,
                            "implementation": "Official",
                        },
                        "bitrate": 5_000_000,
                    }
                ],
                "scenes": [FRONT_SCENE_SETTINGS],
            }
        )

    def run(self):
        filename = Path("files/StreamSrtToFfmpegEncryption.ts")
        self.moblin.set_scene("Front")
        with FfmpegServer(
            url="srt://0.0.0.0:8890?mode=listener&passphrase=1234567890",
            filename=filename,
        ):
            self.moblin.go_live()
            self.moblin.wait_for_bitrate(4_000_000, 6_000_000, None, 10_000_000)
            self.moblin.end()
        self.assert_live_stream(filename)


class StreamSrtToFfmpegVideoRateControl(TestCase):
    """SRT stream from Moblin to ffmpeg for a few seconds using given video rate control."""

    def __init__(self, moblin: Moblin, rate_control: str):
        super().__init__(moblin, f"StreamSrtToFfmpegVideoRateControl{rate_control}")
        self._rate_control = rate_control

    def setup(self):
        if self._rate_control == "ABR":
            self.skip_if_no_moving_picture()
            self.moving_picture_on()
        self.moblin.import_settings(
            overrides={
                "streams": [
                    {
                        "enabled": True,
                        "bitrateRateControl": self._rate_control,
                        "url": f"srt://{self.moblin.config.tester_ip_address()}:8890?streamid=publish:test",
                        "bitrate": 5_000_000,
                    }
                ],
                "scenes": [FRONT_SCENE_SETTINGS],
            }
        )

    def run(self):
        filename = Path(f"files/{self.name}.ts")
        self.moblin.set_scene("Front")
        with FfmpegServer(url="srt://0.0.0.0:8890?mode=listener", filename=filename):
            self.moblin.go_live()
            self.moblin.wait_for_bitrate(4_000_000, 6_000_000, None, 5_000_000)
            self.moblin.end()
        self.assert_live_stream(filename)


class StreamMultiRtmpToMediaMtx(TestCase):
    """Multiple RTMP streams from Moblin to MediaMTX for a few seconds."""

    def setup(self):
        tester_ip_address = self.moblin.config.tester_ip_address()
        self.moblin.import_settings(
            overrides={
                "streams": [
                    {
                        "enabled": True,
                        "bitrateRateControl": "CBR",
                        "url": f"rtmp://{tester_ip_address}:1935/test1",
                        "rtmp": {"adaptiveBitrateEnabled": False},
                        "multiStreaming": {
                            "destinations": [
                                {
                                    "name": "Test 2",
                                    "url": f"rtmp://{tester_ip_address}:1935/test2",
                                    "enabled": True,
                                },
                                {
                                    "name": "Test 3",
                                    "url": f"rtmp://{tester_ip_address}:1935/test3",
                                    "enabled": True,
                                },
                            ]
                        },
                    }
                ],
                "scenes": [FRONT_SCENE_SETTINGS],
            }
        )

    def run(self):
        self.moblin.set_scene("Front")
        with MediaMtx() as mediamtx:
            self.moblin.go_live()
            self.moblin.wait_for_bitrate(4_500_000, 5_500_000, "x3", 30_000_000)
            mediamtx.wait_for_rtmp_stream("test1", 10_000_000)
            mediamtx.wait_for_rtmp_stream("test2", 10_000_000)
            mediamtx.wait_for_rtmp_stream("test3", 10_000_000)
            self.moblin.end()


class StreamToGenericUrls(TestCase):
    """Stream to each generic URL for a few seconds."""

    def __init__(self, moblin: Moblin, number: int, generic_stream_url: str):
        self._generic_stream = format_generic_stream_url_stream_name(
            number, generic_stream_url
        )
        super().__init__(moblin, f"StreamToGenericUrls({self._generic_stream})")
        self._generic_stream_url = generic_stream_url

    def setup(self):
        self.moblin.import_settings(
            overrides={
                "streams": [
                    {
                        "enabled": True,
                        "bitrateRateControl": "CBR",
                        "url": self._generic_stream_url,
                        "codec": "H.264/AVC",
                        "bitrate": 5_000_000,
                    }
                ],
                "scenes": [FRONT_SCENE_SETTINGS],
            }
        )

    def run(self):
        self.moblin.set_scene("Front")
        self.moblin.go_live()
        self.moblin.wait_for_bitrate(4_000_000, 6_000_000, None, 10_000_000)
        self.moblin.end()


def tests(moblin: Moblin):
    return [
        StreamRtmpToMediaMtx(moblin),
        StreamSrtToMediaMtx(moblin),
        StreamSrtToFfmpeg(moblin, fps=30),
        StreamSrtToFfmpeg(moblin, fps=60),
        StreamSrtToFfmpegHighBitrate(moblin),
        StreamSrtToFfmpegEncrypted(moblin),
        StreamSrtToFfmpegVideoRateControl(moblin, "ABR"),
        StreamSrtToFfmpegVideoRateControl(moblin, "CBR"),
        StreamSrtToFfmpegVideoRateControl(moblin, "VBR"),
        StreamMultiRtmpToMediaMtx(moblin),
    ] + [
        StreamToGenericUrls(moblin, number, generic_stream_url)
        for number, generic_stream_url in enumerate(moblin.generic_stream_urls, 1)
    ]
