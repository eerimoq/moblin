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
            self.moblin.set_stream("RTMP test")
            self.moblin.go_live()
            mediamtx.wait_for_rtmp_stream("test", 5000000)
            self.moblin.end()


class StreamSrtFromMoblinToMediaMtx(systest.TestCase):
    """SRT stream from Moblin to MediaMTX for a few seconds."""

    def __init__(self, moblin: Moblin):
        super().__init__()
        self.moblin = moblin

    def run(self):
        with MediaMtx() as mediamtx:
            self.moblin.set_stream("SRT test")
            self.moblin.go_live()
            mediamtx.wait_for_srt_stream("test", 5000000)
            self.moblin.end()
