import systest
from utils.moblin import Moblin
from utils.ffmpeg import Ffmpeg
from utils.mediamtx import MediaMtx


class AllIngestsInParallel(systest.TestCase):
    """Stream to all kinds of ingests in parallel."""

    def __init__(self, moblin: Moblin):
        super().__init__()
        self.moblin = moblin

    def run(self):
        rtmp_server = Ffmpeg("rtmp://1.2.3.4/live/1")
        srt_server = Ffmpeg("srt://1.2.3.4:4000?streamid=1")
        srt_client = Ffmpeg("srt://1.2.3.4:4000?streamid=1")
        rist_server = Ffmpeg("rist://1.2.3.4/live/1")
        rtsp_client = Ffmpeg("rtsp://1.2.3.4/live/1")
        whip_server = Ffmpeg("whip://1.2.3.4/live/1")
        whep_client = Ffmpeg("whep://1.2.3.4/live/1")
        with MediaMtx():
            with rtmp_server, srt_server, srt_client, rist_server:
                with rtsp_client, whip_server, whep_client:
                    self.moblin.wait_for_ingests(7)
