import logging

from utils.config import RIST_SERVER_PORT
from utils.config import RTMP_SERVER_PORT
from utils.config import SRT_CLIENT_1_SERVER_PORT
from utils.config import SRT_SERVER_PORT
from utils.config import TESTER_RTMP_PORT
from utils.config import TESTER_RTSP_PORT
from utils.config import WHIP_SERVER_PORT
from utils.config import srt_listener_url
from utils.ffmpeg import FfmpegTestStream
from utils.ffmpeg import FfmpegWhipTestStream
from utils.generate_device_settings import RECORD_STREAM_SETTINGS
from utils.generate_device_settings import uuid
from utils.mediamtx import MediaMtx
from utils.moblin import Moblin
from utils.moblin import Recorder
from utils.test_case import TestCase

LOGGER = logging.getLogger(__name__)
RTMP_STREAM_ID = uuid()
RTSP_STREAM_ID = uuid()
RIST_STREAM_ID = uuid()
SRT_STREAM_ID = uuid()
SRT_CLIENT_STREAM_ID = uuid()
WHIP_STREAM_ID = uuid()
WHEP_STREAM_ID = uuid()


class IngestTestCase(TestCase):
    def import_settings(self, scene, **overrides):
        self.moblin.import_settings(
            overrides={
                "streams": [RECORD_STREAM_SETTINGS],
                "scenes": [scene | {"enabled": True, "overrideMic": True}],
                "widgets": [],
                **overrides,
            }
        )


class IngestRtmpServer(IngestTestCase):
    """Stream to an RTMP server ingest."""

    def setup(self):
        self.import_settings(
            scene={
                "cameraPosition": "RTMP",
                "rtmpCameraId": RTMP_STREAM_ID,
                "micId": f"{RTMP_STREAM_ID} 0",
            },
            rtmpServer={
                "enabled": True,
                "port": RTMP_SERVER_PORT,
                "streams": [{"id": RTMP_STREAM_ID, "name": "1", "streamKey": "1"}],
            },
        )

    def run(self):
        stream = FfmpegTestStream(
            url=f"rtmp://{self.moblin.ip_address}:{RTMP_SERVER_PORT}/live/1"
        )
        recorder = Recorder(self.moblin, "IngestRtmpServer.mp4")
        with stream:
            self.wait_for_ingest_stream_started()
            with recorder:
                self.moblin.wait_for_ingests(
                    minimim_bitrate=7_000_000,
                    maximum_bitrate=9_000_000,
                    total_bytes=10_000_000,
                    number_of_ingests=1,
                )
        self.assert_recording(recorder.recording, has_audio_time_codes=True)


class IngestSrtServer(IngestTestCase):
    """Stream to an SRT server ingest."""

    def setup(self):
        self.import_settings(
            scene={
                "cameraPosition": "SRT(LA)",
                "srtlaCameraId": SRT_STREAM_ID,
                "micId": f"{SRT_STREAM_ID} 0",
            },
            srtlaServer={
                "enabled": True,
                "srtPort": SRT_SERVER_PORT,
                "streams": [{"id": SRT_STREAM_ID, "name": "Test", "streamId": "1"}],
            },
        )

    def run(self):
        stream = FfmpegTestStream(
            url=f"srt://{self.moblin.ip_address}:{SRT_SERVER_PORT}?streamid=1",
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
                    number_of_ingests=1,
                )
        self.assert_recording(recorder.recording)


class IngestSrtClient(IngestTestCase):
    """Stream to an SRT client ingest."""

    def setup(self):
        url = self.moblin.tester_srt_url(SRT_CLIENT_1_SERVER_PORT)
        self.import_settings(
            scene={
                "cameraPosition": "SRT client",
                "srtClientCameraId": SRT_CLIENT_STREAM_ID,
                "micId": f"{SRT_CLIENT_STREAM_ID} 0",
            },
            srtClient={
                "streams": [
                    {
                        "id": SRT_CLIENT_STREAM_ID,
                        "name": "1",
                        "url": url,
                        "enabled": True,
                    }
                ],
            },
        )

    def run(self):
        stream = FfmpegTestStream(
            url=srt_listener_url(SRT_CLIENT_1_SERVER_PORT, stream_id="1"),
            transport_format="mpegts",
        )
        recorder = Recorder(self.moblin, "IngestSrtClient.mp4")
        with stream:
            self.wait_for_ingest_stream_started()
            with recorder:
                self.moblin.wait_for_ingests(
                    minimim_bitrate=7_000_000,
                    maximum_bitrate=9_000_000,
                    total_bytes=10_000_000,
                    number_of_ingests=1,
                )
        self.assert_recording(recorder.recording)


class IngestRtspClientH264(IngestTestCase):
    """Stream to an RTSP client ingest."""

    def setup(self):
        self.import_settings(
            scene={
                "cameraPosition": "RTSP",
                "rtspCameraId": RTSP_STREAM_ID,
                "micId": f"{RTSP_STREAM_ID} 0",
            },
            rtspClient={
                "streams": [
                    {
                        "id": RTSP_STREAM_ID,
                        "name": "1",
                        "url": self.moblin.tester_rtsp_url("1"),
                        "enabled": True,
                    }
                ],
            },
        )

    def run(self):
        recorder = Recorder(self.moblin, "IngestRtspClientH264.mp4")
        with MediaMtx() as mediamtx:
            with FfmpegTestStream(url=f"rtmp://localhost:{TESTER_RTMP_PORT}/1"):
                mediamtx.wait_for_rtsp_stream(2_000_000)
                self.wait_for_ingest_stream_started(startup_delay=5)
                with recorder:
                    self.moblin.wait_for_ingests(
                        minimim_bitrate=7_000_000,
                        maximum_bitrate=9_000_000,
                        total_bytes=10_000_000,
                        number_of_ingests=1,
                    )
        self.assert_recording(recorder.recording)


class IngestRistServer(IngestTestCase):
    """Stream to an RIST server ingest."""

    def setup(self):
        self.import_settings(
            scene={
                "cameraPosition": "RIST",
                "ristCameraId": RIST_STREAM_ID,
                "micId": f"{RIST_STREAM_ID} 0",
            },
            ristServer={
                "enabled": True,
                "port": RIST_SERVER_PORT,
                "streams": [
                    {"id": RIST_STREAM_ID, "name": "1", "virtualDestinationPort": 1}
                ],
            },
        )

    def run(self):
        stream = FfmpegTestStream(
            url=f"rist://{self.moblin.ip_address}:{RIST_SERVER_PORT}?virt-dst-port=1",
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
                    number_of_ingests=1,
                )
        self.assert_recording(recorder.recording)


class IngestWhipServer(IngestTestCase):
    """Stream to a WHIP server ingest."""

    def setup(self):
        self.import_settings(
            scene={
                "cameraPosition": "WHIP",
                "whipCameraId": WHIP_STREAM_ID,
                "micId": f"{WHIP_STREAM_ID} 0",
            },
            whipServer={
                "enabled": True,
                "port": WHIP_SERVER_PORT,
                "streams": [
                    {
                        "id": WHIP_STREAM_ID,
                        "name": "1",
                        "streamKey": "1",
                        "latency": 2000,
                    }
                ],
            },
        )

    def run(self):
        stream = FfmpegWhipTestStream(
            url=f"http://{self.moblin.ip_address}:{WHIP_SERVER_PORT}/whip/stream/1",
        )
        recorder = Recorder(self.moblin, "IngestWhipServer.mp4")
        with stream:
            self.wait_for_ingest_stream_started(startup_delay=5)
            with recorder:
                self.moblin.wait_for_ingests(
                    minimim_bitrate=7_000_000,
                    maximum_bitrate=9_000_000,
                    total_bytes=10_000_000,
                    number_of_ingests=1,
                )
        self.assert_recording(recorder.recording, channels=1)


class IngestWhepClient(IngestTestCase):
    """Stream to a WHEP client ingest."""

    def setup(self):
        self.import_settings(
            scene={
                "cameraPosition": "WHEP",
                "whepCameraId": WHEP_STREAM_ID,
                "micId": f"{WHEP_STREAM_ID} 0",
            },
            whepClient={
                "streams": [
                    {
                        "id": WHEP_STREAM_ID,
                        "name": "1",
                        "url": self.moblin.tester_whep_url("1"),
                        "enabled": True,
                        "latency": 2000,
                    }
                ],
            },
        )

    def run(self):
        stream = FfmpegTestStream(
            url=f"rtsp://localhost:{TESTER_RTSP_PORT}/1",
            transport_format="rtsp",
            video_profile="baseline",
            audio_codec="libopus",
            audio_channels=2,
            muxer_args=["-rtsp_transport", "tcp"],
        )
        recorder = Recorder(self.moblin, "IngestWhepClient.mp4")
        with MediaMtx() as mediamtx:
            with stream:
                mediamtx.wait_for_rtsp_publisher("1", 2_000_000)
                self.wait_for_ingest_stream_started(startup_delay=5)
                with recorder:
                    self.moblin.wait_for_ingests(
                        minimim_bitrate=7_000_000,
                        maximum_bitrate=9_000_000,
                        total_bytes=10_000_000,
                        number_of_ingests=1,
                    )
        self.assert_recording(recorder.recording, channels=1)


def tests(moblin: Moblin):
    return [
        IngestRtmpServer(moblin),
        IngestSrtServer(moblin),
        IngestSrtClient(moblin),
        IngestRtspClientH264(moblin),
        IngestRistServer(moblin),
        IngestWhipServer(moblin),
        IngestWhepClient(moblin),
    ]
