from pathlib import Path

from utils.config import RIST_SERVER_PORT
from utils.config import RTMP_SERVER_PORT
from utils.config import SRT_CLIENT_1_SERVER_PORT
from utils.config import SRT_SERVER_PORT
from utils.config import TESTER_RTMP_PORT
from utils.config import WHIP_SERVER_PORT
from utils.config import rtsp_reader_url
from utils.config import srt_listener_url
from utils.ffmpeg import FfmpegRtspTestStream
from utils.ffmpeg import FfmpegTestStream
from utils.ffmpeg import FfmpegWhipTestStream
from utils.ffmpeg import TransportFormat
from utils.generate_device_settings import RECORD_STREAM_SETTINGS
from utils.generate_device_settings import CameraPosition
from utils.generate_device_settings import mic_id
from utils.generate_device_settings import uuid
from utils.mediamtx import MediaMtx
from utils.moblin import Moblin
from utils.moblin import Recorder
from utils.test_case import TestCase
from utils.utils import Range

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
                **overrides,
            }
        )

    def record_ingest(self, startup_delay: float = 1) -> Path:
        recorder = Recorder(self.moblin, f"{self.name}.mp4")
        self.wait_for_ingest_stream_started(startup_delay=startup_delay)
        with recorder:
            self.moblin.wait_for_ingests(
                bitrate=Range(7_000_000, 9_000_000),
                total_bytes=10_000_000,
                number_of_ingests=1,
            )
        return recorder.recording


class IngestRtmpServer(IngestTestCase):
    """Stream to an RTMP server ingest."""

    def setup(self):
        self.import_settings(
            scene={
                "cameraPosition": CameraPosition.RTMP,
                "rtmpCameraId": RTMP_STREAM_ID,
                "micId": mic_id(RTMP_STREAM_ID),
            },
            rtmpServer={
                "enabled": True,
                "port": RTMP_SERVER_PORT,
                "streams": [{"id": RTMP_STREAM_ID, "name": "1", "streamKey": "1"}],
            },
        )

    def run(self):
        with FfmpegTestStream(url=self.moblin.ingest_rtmp_url()):
            recording = self.record_ingest()
        self.assert_recording(recording, has_audio_time_codes=True)


class IngestSrtServer(IngestTestCase):
    """Stream to an SRT server ingest."""

    def setup(self):
        self.import_settings(
            scene={
                "cameraPosition": CameraPosition.SRTLA,
                "srtlaCameraId": SRT_STREAM_ID,
                "micId": mic_id(SRT_STREAM_ID),
            },
            srtlaServer={
                "enabled": True,
                "srtPort": SRT_SERVER_PORT,
                "streams": [{"id": SRT_STREAM_ID, "name": "Test", "streamId": "1"}],
            },
        )

    def run(self):
        stream = FfmpegTestStream(
            url=self.moblin.ingest_srt_url(),
            transport_format=TransportFormat.MPEGTS,
        )
        with stream:
            recording = self.record_ingest()
        self.assert_recording(recording)


class IngestSrtClient(IngestTestCase):
    """Stream to an SRT client ingest."""

    def setup(self):
        self.import_settings(
            scene={
                "cameraPosition": CameraPosition.SRT_CLIENT,
                "srtClientCameraId": SRT_CLIENT_STREAM_ID,
                "micId": mic_id(SRT_CLIENT_STREAM_ID),
            },
            srtClient={
                "streams": [
                    {
                        "id": SRT_CLIENT_STREAM_ID,
                        "name": "1",
                        "url": self.moblin.tester_srt_url(SRT_CLIENT_1_SERVER_PORT),
                        "enabled": True,
                    }
                ],
            },
        )

    def run(self):
        stream = FfmpegTestStream(
            url=srt_listener_url(SRT_CLIENT_1_SERVER_PORT, stream_id="1"),
            transport_format=TransportFormat.MPEGTS,
        )
        with stream:
            recording = self.record_ingest()
        self.assert_recording(recording)


class IngestRtspClientH264(IngestTestCase):
    """Stream to an RTSP client ingest."""

    def setup(self):
        self.import_settings(
            scene={
                "cameraPosition": CameraPosition.RTSP,
                "rtspCameraId": RTSP_STREAM_ID,
                "micId": mic_id(RTSP_STREAM_ID),
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
        with MediaMtx() as mediamtx:
            with FfmpegTestStream(url=f"rtmp://localhost:{TESTER_RTMP_PORT}/1"):
                mediamtx.wait_for_rtsp_stream(2_000_000)
                recording = self.record_ingest(startup_delay=5)
        self.assert_recording(recording)


class IngestRistServer(IngestTestCase):
    """Stream to an RIST server ingest."""

    def setup(self):
        self.import_settings(
            scene={
                "cameraPosition": CameraPosition.RIST,
                "ristCameraId": RIST_STREAM_ID,
                "micId": mic_id(RIST_STREAM_ID),
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
            url=self.moblin.ingest_rist_url(),
            transport_format=TransportFormat.MPEGTS,
        )
        with stream:
            recording = self.record_ingest(startup_delay=5)
        self.assert_recording(recording)


class IngestWhipServer(IngestTestCase):
    """Stream to a WHIP server ingest."""

    def setup(self):
        self.import_settings(
            scene={
                "cameraPosition": CameraPosition.WHIP,
                "whipCameraId": WHIP_STREAM_ID,
                "micId": mic_id(WHIP_STREAM_ID),
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
        with FfmpegWhipTestStream(url=self.moblin.ingest_whip_url()):
            recording = self.record_ingest(startup_delay=5)
        self.assert_recording(recording)


class IngestWhepClient(IngestTestCase):
    """Stream to a WHEP client ingest."""

    def setup(self):
        self.import_settings(
            scene={
                "cameraPosition": CameraPosition.WHEP,
                "whepCameraId": WHEP_STREAM_ID,
                "micId": mic_id(WHEP_STREAM_ID),
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
        with MediaMtx() as mediamtx:
            with FfmpegRtspTestStream(url=rtsp_reader_url("1")):
                mediamtx.wait_for_rtsp_publisher("1", 2_000_000)
                recording = self.record_ingest(startup_delay=5)
        self.assert_recording(recording)


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
