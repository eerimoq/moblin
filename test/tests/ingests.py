import time

import systest
from utils.moblin import Moblin
from utils.ffmpeg import Ffmpeg


class StreamToRtmpIngest(systest.TestCase):
    """Stream to all kinds of ingests in parallel."""

    def __init__(self, moblin: Moblin):
        super().__init__()
        self.moblin = moblin

    def run(self):
        rtmp_server = Ffmpeg(f"rtmp://{self.moblin.ip_address}:11935/live/1")
        with rtmp_server:
            time.sleep(10)
            # self.moblin.wait_for_ingests(1)
