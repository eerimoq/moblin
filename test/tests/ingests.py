import systest
from utils.moblin import Moblin
from utils.ffmpeg import FfmpegTestStream
from utils.mediamtx import MediaMtx


class StreamToRtmpServerIngest(systest.TestCase):
    """Stream to an RTMP server ingest."""

    def __init__(self, moblin: Moblin):
        super().__init__()
        self.moblin = moblin

    def run(self):
        self.moblin.set_scene("RTMP")
        rtmp_stream = FfmpegTestStream(
            url=f"rtmp://{self.moblin.ip_address}:11935/live/1"
        )
        with rtmp_stream:
            self.moblin.wait_for_ingests(
                minimim_bitrate=7_000_000,
                maximum_bitrate=9_000_000,
                total_bytes=10_000_000,
                number_of_ingests=2,
            )


class StreamH264ToRtspClientIngest(systest.TestCase):
    """Stream to an RTSP client ingest."""

    def __init__(self, moblin: Moblin):
        super().__init__()
        self.moblin = moblin

    def run(self):
        self.moblin.set_scene("RTSP")
        with MediaMtx():
            rtmp_stream = FfmpegTestStream(url="rtmp://localhost:1935/1")
            with rtmp_stream:
                self.moblin.wait_for_ingests(
                    minimim_bitrate=7_000_000,
                    maximum_bitrate=9_000_000,
                    total_bytes=10_000_000,
                    number_of_ingests=1,
                )


class StreamToRistServerIngest(systest.TestCase):
    """Stream to an RIST server ingest."""

    def __init__(self, moblin: Moblin):
        super().__init__()
        self.moblin = moblin

    def run(self):
        self.moblin.set_scene("RIST")
        rtmp_stream = FfmpegTestStream(
            url=f"rist://{self.moblin.ip_address}:6500?virt-dst-port=1",
            transport_format="mpegts",
        )
        with rtmp_stream:
            self.moblin.wait_for_ingests(
                minimim_bitrate=7_000_000,
                maximum_bitrate=9_000_000,
                total_bytes=10_000_000,
                number_of_ingests=2,
            )
