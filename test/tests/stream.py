import systest
from utils.ffmpeg import FfmpegServer
from utils.moblin import Moblin
from utils.mediamtx import MediaMtx


class StreamRtmpFromMoblinToMediaMtx(systest.TestCase):
    """RTMP stream from Moblin to MediaMTX for a few seconds."""

    def __init__(self, moblin: Moblin):
        super().__init__()
        self.moblin = moblin

    def run(self):
        self.moblin.set_scene("Front")
        with MediaMtx() as mediamtx:
            self.moblin.set_stream("RTMP")
            self.moblin.go_live()
            self.moblin.wait_for_bitrate(4_500_000, 5_500_000, None, 5_000_000)
            mediamtx.wait_for_rtmp_stream("test", 5_000_000)
            self.moblin.end()


class StreamSrtFromMoblinToMediaMtx(systest.TestCase):
    """SRT stream from Moblin to MediaMTX for a few seconds."""

    def __init__(self, moblin: Moblin):
        super().__init__()
        self.moblin = moblin

    def run(self):
        self.moblin.set_scene("Front")
        with MediaMtx() as mediamtx:
            self.moblin.set_stream("SRT")
            self.moblin.go_live()
            self.moblin.wait_for_bitrate(49_000_000, 51_000_000, None, 50_000_000)
            mediamtx.wait_for_srt_stream("test", 50_000_000)
            self.moblin.end()


class StreamSrtFromMoblinToFfmpeg(systest.TestCase):
    """SRT stream from Moblin to ffmpeg for a few seconds."""

    def __init__(self, moblin: Moblin):
        super().__init__()
        self.moblin = moblin

    def run(self):
        self.moblin.set_scene("Front")
        with FfmpegServer(url="srt://0.0.0.0:8890?mode=listener"):
            self.moblin.set_stream("SRT 5Mbps")
            self.moblin.go_live()
            self.moblin.wait_for_bitrate(4_000_000, 6_000_000, None, 5_000_000)
            self.moblin.end()


class StreamMultiRtmpFromMoblinToMediaMtx(systest.TestCase):
    """Multiple RTMP streams from Moblin to MediaMTX for a few seconds."""

    def __init__(self, moblin: Moblin):
        super().__init__()
        self.moblin = moblin

    def run(self):
        self.moblin.set_scene("Front")
        with MediaMtx() as mediamtx:
            self.moblin.set_stream("Multi RTMP")
            self.moblin.go_live()
            self.moblin.wait_for_bitrate(4_500_000, 5_500_000, "x3", 15_000_000)
            mediamtx.wait_for_rtmp_stream("test1", 5_000_000)
            mediamtx.wait_for_rtmp_stream("test2", 5_000_000)
            mediamtx.wait_for_rtmp_stream("test3", 5_000_000)
            self.moblin.end()
