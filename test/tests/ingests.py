import logging

from utils.recorder import Recorder
from utils.moblin import Moblin
from utils.ffmpeg import FfmpegTestStream
from utils.mediamtx import MediaMtx
from utils.test_case import TestCase

LOGGER = logging.getLogger(__name__)


class IngestRtmpServer(TestCase):
    """Stream to an RTMP server ingest."""

    def run(self):
        self.moblin.set_scene("RTMP")
        stream = FfmpegTestStream(url=f"rtmp://{self.moblin.ip_address}:11935/live/1")
        recorder = Recorder(self.moblin, "IngestRtmpServer.mp4")
        with stream:
            self.wait_for_ingest_stream_started()
            with recorder:
                self.moblin.wait_for_ingests(
                    minimim_bitrate=7_000_000,
                    maximum_bitrate=9_000_000,
                    total_bytes=10_000_000,
                    number_of_ingests=2,
                )
        self.assert_recording(recorder.recording)


class IngestSrtServer(TestCase):
    """Stream to an SRT server ingest."""

    def run(self):
        self.moblin.set_scene("SRT")
        stream = FfmpegTestStream(
            url=f"srt://{self.moblin.ip_address}:4000?streamid=1",
            transport_format="mpegts",
        )
        recorder = Recorder(self.moblin, "IngestSrtServer.mp4")
        with stream:
            self.wait_for_ingest_stream_started()
            with recorder:
                self.moblin.wait_for_ingests(
                    minimim_bitrate=7_000_000,
                    maximum_bitrate=9_000_000,
                    total_bytes=10_000_000,
                    number_of_ingests=2,
                )
        self.assert_recording(recorder.recording)


class IngestRtspClientH264(TestCase):
    """Stream to an RTSP client ingest."""

    def run(self):
        self.moblin.set_scene("RTSP")
        recorder = Recorder(self.moblin, "IngestRtspClientH264.mp4")
        with MediaMtx() as mediamtx:
            with FfmpegTestStream(url="rtmp://localhost:1935/1"):
                mediamtx.wait_for_rtsp_stream(2_000_000)
                self.wait_for_ingest_stream_started(
                    number_of_ingests=1, startup_delay=5
                )
                with recorder:
                    self.moblin.wait_for_ingests(
                        minimim_bitrate=7_000_000,
                        maximum_bitrate=9_000_000,
                        total_bytes=10_000_000,
                        number_of_ingests=1,
                    )
        self.assert_recording(recorder.recording)


class IngestRistServer(TestCase):
    """Stream to an RIST server ingest."""

    def run(self):
        self.moblin.set_scene("RIST")
        stream = FfmpegTestStream(
            url=f"rist://{self.moblin.ip_address}:6500?virt-dst-port=1",
            transport_format="mpegts",
        )
        recorder = Recorder(self.moblin, "IngestRistServer.mp4")
        with stream:
            self.wait_for_ingest_stream_started(startup_delay=5)
            with recorder:
                self.moblin.wait_for_ingests(
                    minimim_bitrate=7_000_000,
                    maximum_bitrate=9_000_000,
                    total_bytes=10_000_000,
                    number_of_ingests=2,
                )
        self.assert_recording(recorder.recording)


def tests(moblin: Moblin):
    return [
        IngestRtmpServer(moblin),
        IngestSrtServer(moblin),
        IngestRtspClientH264(moblin),
        IngestRistServer(moblin),
    ]
