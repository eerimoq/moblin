import systest
from utils.moblin import Moblin
from utils.mediamtx import MediaMtx


class StreamRtmpFromMoblinToMediaMtx(systest.TestCase):
    """RTMP stream from Moblin to MediaMTX for a few seconds."""

    def __init__(self, moblin: Moblin):
        super().__init__()
        self.moblin = moblin

    def run(self):
        with MediaMtx() as mediamtx:
            self.moblin.set_stream("RTMP")
            self.moblin.go_live()
            mediamtx.wait_for_rtmp_stream("test", 5_000_000)
            self.moblin.end()


class StreamSrtFromMoblinToMediaMtx(systest.TestCase):
    """SRT stream from Moblin to MediaMTX for a few seconds."""

    def __init__(self, moblin: Moblin):
        super().__init__()
        self.moblin = moblin

    def run(self):
        with MediaMtx() as mediamtx:
            self.moblin.set_stream("SRT")
            self.moblin.go_live()
            mediamtx.wait_for_srt_stream("test", 50_000_000)
            self.moblin.end()


class StreamMultiRtmpFromMoblinToMediaMtx(systest.TestCase):
    """Multiple RTMP streams from Moblin to MediaMTX for a few seconds."""

    def __init__(self, moblin: Moblin):
        super().__init__()
        self.moblin = moblin

    def run(self):
        with MediaMtx() as mediamtx:
            self.moblin.set_stream("Multi RTMP")
            self.moblin.go_live()
            mediamtx.wait_for_rtmp_stream("test1", 5_000_000)
            mediamtx.wait_for_rtmp_stream("test2", 5_000_000)
            mediamtx.wait_for_rtmp_stream("test3", 5_000_000)
            self.moblin.end()
