import systest
from utils.moblin import Moblin
from utils.ffmpeg import FfmpegTestStream
from utils.mediamtx import MediaMtx


class IngestRtmpServer(systest.TestCase):
    """Stream to an RTMP server ingest."""

    def __init__(self, moblin: Moblin):
        super().__init__()
        self.moblin = moblin

    def run(self):
        self.moblin.set_scene("RTMP")
        stream = FfmpegTestStream(url=f"rtmp://{self.moblin.ip_address}:11935/live/1")
        with stream:
            self.moblin.wait_for_ingests(
                minimim_bitrate=7_000_000,
                maximum_bitrate=9_000_000,
                total_bytes=10_000_000,
                number_of_ingests=2,
            )


class IngestSrtServer(systest.TestCase):
    """Stream to an SRT server ingest."""

    def __init__(self, moblin: Moblin):
        super().__init__()
        self.moblin = moblin

    def run(self):
        self.moblin.set_scene("SRT")
        stream = FfmpegTestStream(
            url=f"srt://{self.moblin.ip_address}:4000?streamid=1",
            transport_format="mpegts",
        )
        with stream:
            self.moblin.wait_for_ingests(
                minimim_bitrate=7_000_000,
                maximum_bitrate=9_000_000,
                total_bytes=10_000_000,
                number_of_ingests=2,
            )


class IngestRtspClientH264(systest.TestCase):
    """Stream to an RTSP client ingest."""

    def __init__(self, moblin: Moblin):
        super().__init__()
        self.moblin = moblin

    def run(self):
        self.moblin.set_scene("RTSP")
        with MediaMtx():
            with FfmpegTestStream(url="rtmp://localhost:1935/1"):
                self.moblin.wait_for_ingests(
                    minimim_bitrate=7_000_000,
                    maximum_bitrate=9_000_000,
                    total_bytes=10_000_000,
                    number_of_ingests=1,
                )


class IngestRistServer(systest.TestCase):
    """Stream to an RIST server ingest."""

    def __init__(self, moblin: Moblin):
        super().__init__()
        self.moblin = moblin

    def run(self):
        self.moblin.set_scene("RIST")
        stream = FfmpegTestStream(
            url=f"rist://{self.moblin.ip_address}:6500?virt-dst-port=1",
            transport_format="mpegts",
        )
        with stream:
            self.moblin.wait_for_ingests(
                minimim_bitrate=7_000_000,
                maximum_bitrate=9_000_000,
                total_bytes=10_000_000,
                number_of_ingests=2,
            )


def tests(moblin: Moblin):
    return [
        IngestRtmpServer(moblin),
        IngestSrtServer(moblin),
        IngestRtspClientH264(moblin),
        IngestRistServer(moblin),
    ]
