import logging
from pathlib import Path

from utils.ffmpeg import FfmpegServer
from utils.ffmpeg import ffprobe
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

    def run(self):
        filename = Path("files/StreamSrtFromMoblinToFfmpeg.ts")
        self.moblin.set_scene("Front")
        with FfmpegServer(url="srt://0.0.0.0:8890?mode=listener", filename=filename):
            self.moblin.set_stream("SRT 5Mbps")
            self.moblin.go_live()
            self.moblin.wait_for_bitrate(4_000_000, 6_000_000, None, 10_000_000)
            self.moblin.end()
            metadata = ffprobe(filename)
            self.assert_equal(metadata.video.codec, "hevc")
            self.assert_equal(metadata.audio.codec, "aac")
            self.assert_greater(metadata.format.duration, 10)
            self.assert_less(metadata.format.duration, 20)


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
            metadata = ffprobe(filename)
            self.assert_equal(metadata.video.codec, "hevc")
            self.assert_equal(metadata.audio.codec, "aac")
            self.assert_greater(metadata.format.duration, 1)
            self.assert_less(metadata.format.duration, 10)


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
            metadata = ffprobe(filename)
            self.assert_equal(metadata.video.codec, "hevc")
            self.assert_equal(metadata.audio.codec, "aac")
            self.assert_greater(metadata.format.duration, 10)
            self.assert_less(metadata.format.duration, 20)


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

    def run(self):
        self.moblin.set_scene("Front")
        for generic_stream in self.moblin.generic_streams:
            LOGGER.info("Stream: %s", generic_stream)
            self.moblin.set_stream(generic_stream)
            self.moblin.go_live()
            self.moblin.wait_for_bitrate(4_000_000, 6_000_000, None, 10_000_000)
            self.moblin.end()


def tests(moblin: Moblin):
    return [
        StreamRtmpToMediaMtx(moblin),
        StreamSrtToMediaMtx(moblin),
        StreamSrtToFfmpeg(moblin),
        StreamSrtToFfmpegHighBitrate(moblin),
        StreamSrtToFfmpegEncrypted(moblin),
        StreamMultiRtmpToMediaMtx(moblin),
        StreamToGenericUrls(moblin),
    ]
