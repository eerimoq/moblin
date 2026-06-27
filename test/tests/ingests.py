import systest
from utils.moblin import Moblin
from utils.ffmpeg import FfmpegTestStream


class StreamToRtmpIngest(systest.TestCase):
    """Stream to the an RTMP server ingest."""

    def __init__(self, moblin: Moblin):
        super().__init__()
        self.moblin = moblin

    def run(self):
        rtmp_stream = FfmpegTestStream(
            url=f"rtmp://{self.moblin.ip_address}:11935/live/1", video_codec="libx264"
        )
        with rtmp_stream:
            self.moblin.wait_for_ingests(
                minimim_bitrate=7_000_000,
                maximum_bitrate=9_000_000,
                total_bytes=10_000_000,
                number_of_ingests=1,
            )
