import logging
from pathlib import Path

from utils.ffmpeg import FfmpegServer
from utils.mediamtx import MediaMtx
from utils.moblin import Moblin
from utils.test_case import TestCase

LOGGER = logging.getLogger(__name__)


class StreamRtmpToMediaMtx(TestCase):
    """RTMP stream from Moblin to MediaMTX for a few seconds."""

    def run(self):
        self.moblin.set_scene("Front")
        with MediaMtx() as mediamtx:
            self.moblin.set_stream("RTMP")
            self.moblin.go_live()
            self.moblin.wait_for_bitrate(4_500_000, 5_500_000, None, 10_000_000)
            mediamtx.wait_for_rtmp_stream("test", 10_000_000)
            self.moblin.end()


class StreamSrtToMediaMtx(TestCase):
    """SRT stream from Moblin to MediaMTX for a few seconds."""

    def run(self):
        self.moblin.set_scene("Front")
        with MediaMtx() as mediamtx:
            self.moblin.set_stream("SRT")
            self.moblin.go_live()
            self.moblin.wait_for_bitrate(49_000_000, 51_000_000, None, 100_000_000)
            mediamtx.wait_for_srt_stream("test", 100_000_000)
            self.moblin.end()


class StreamSrtToFfmpeg(TestCase):
    """SRT stream from Moblin to ffmpeg for a few seconds."""

    def __init__(self, moblin: Moblin, fps: int):
        super().__init__(moblin, f"StreamSrtToFfmpeg{fps}Fps")
        self._fps = fps

    def run(self):
        filename = Path(f"files/{self.name}.ts")
        self.moblin.set_scene("Front")
        with FfmpegServer(url="srt://0.0.0.0:8890?mode=listener", filename=filename):
            self.moblin.set_stream(f"SRT 5Mbps 1080@{self._fps}")
            self.moblin.go_live()
            self.moblin.wait_for_bitrate(4_000_000, 6_000_000, None, 10_000_000)
            self.moblin.end()
        self.assert_live_stream(filename)


class StreamSrtToFfmpegHighBitrate(TestCase):
    """SRT stream from Moblin to ffmpeg at 50 Mbps for a few seconds."""

    def run(self):
        filename = Path("files/StreamSrtFromMoblinToFfmpegHighBitrate.ts")
        self.moblin.set_scene("Front")
        with FfmpegServer(url="srt://0.0.0.0:8890?mode=listener", filename=filename):
            self.moblin.set_stream("SRT")
            self.moblin.go_live()
            self.moblin.wait_for_bitrate(49_000_000, 51_000_000, None, 50_000_000)
            self.moblin.end()
        self.assert_live_stream(filename, minimum_length=1, maximum_length=10)


class StreamSrtToFfmpegEncrypted(TestCase):
    """Encrypted SRT stream from Moblin to ffmpeg for a few seconds."""

    def run(self):
        filename = Path("files/StreamSrtToFfmpegEncryption.ts")
        self.moblin.set_scene("Front")
        with FfmpegServer(
            url="srt://0.0.0.0:8890?mode=listener&passphrase=1234567890",
            filename=filename,
        ):
            self.moblin.set_stream("SRT encrypted")
            self.moblin.go_live()
            self.moblin.wait_for_bitrate(4_000_000, 6_000_000, None, 10_000_000)
            self.moblin.end()
        self.assert_live_stream(filename)


class StreamSrtToFfmpegVideoRateControl(TestCase):
    """SRT stream from Moblin to ffmpeg for a few seconds using given video rate control."""

    def __init__(self, moblin: Moblin, rate_control: str):
        super().__init__(moblin, f"StreamSrtToFfmpegVideoRateControl{rate_control}")
        self._rate_control = rate_control

    def run(self):
        filename = Path(f"files/{self.name}.ts")
        self.moblin.set_scene("Front")
        with FfmpegServer(url="srt://0.0.0.0:8890?mode=listener", filename=filename):
            self.moblin.set_stream(f"SRT adaptive {self._rate_control}")
            self.moblin.go_live()
            self.moblin.wait_for_bitrate(4_000_000, 6_000_000, None, 5_000_000)
            self.moblin.end()
        self.assert_live_stream(filename)


class StreamMultiRtmpToMediaMtx(TestCase):
    """Multiple RTMP streams from Moblin to MediaMTX for a few seconds."""

    def run(self):
        self.moblin.set_scene("Front")
        with MediaMtx() as mediamtx:
            self.moblin.set_stream("Multi RTMP")
            self.moblin.go_live()
            self.moblin.wait_for_bitrate(4_500_000, 5_500_000, "x3", 30_000_000)
            mediamtx.wait_for_rtmp_stream("test1", 10_000_000)
            mediamtx.wait_for_rtmp_stream("test2", 10_000_000)
            mediamtx.wait_for_rtmp_stream("test3", 10_000_000)
            self.moblin.end()


class StreamToGenericUrls(TestCase):
    """Stream to each generic URL for a few seconds."""

    def __init__(self, moblin: Moblin, generic_stream: str):
        super().__init__(moblin, f"StreamToGenericUrls({generic_stream})")
        self._generic_stream = generic_stream

    def run(self):
        self.moblin.set_scene("Front")
        self.moblin.set_stream(self._generic_stream)
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
        StreamToGenericUrls(moblin, generic_stream=generic_stream)
        for generic_stream in moblin.generic_streams
    ]
