from pathlib import Path

from ..utils.common.ffmpeg import FfmpegRtspTestStream
from ..utils.common.ffmpeg import FfmpegTestStream
from ..utils.common.ffmpeg import FfmpegVideoCodec
from ..utils.common.ffmpeg import FfmpegWhipTestStream
from ..utils.common.ffmpeg import TransportFormat
from ..utils.config import RIST_SERVER_PORT
from ..utils.config import RTMP_SERVER_PORT
from ..utils.config import SRT_CLIENT_1_SERVER_PORT
from ..utils.config import SRT_CLIENT_2_SERVER_PORT
from ..utils.config import SRT_SERVER_PORT
from ..utils.config import TESTER_RTMP_PORT
from ..utils.config import WHIP_SERVER_PORT
from ..utils.config import rtsp_reader_url
from ..utils.config import srt_listener_url
from ..utils.generate_device_settings import RECORD_STREAM_SETTINGS
from ..utils.generate_device_settings import Alignment
from ..utils.generate_device_settings import CameraPosition
from ..utils.generate_device_settings import VideoCodec
from ..utils.generate_device_settings import mic_id
from ..utils.generate_device_settings import scene_widget_settings
from ..utils.generate_device_settings import uuid
from ..utils.generate_device_settings import video_source_widget_settings
from ..utils.mediamtx import MediaMtx
from ..utils.moblin import Moblin
from ..utils.moblin import Recorder
from ..utils.test_case import TestCase
from ..utils.utils import FILES_DIR
from ..utils.utils import Range

STREAM_ID = uuid()
STREAM_2_ID = uuid()
SECOND_INGEST_WIDGET_ID = uuid()
FFMPEG_VIDEO_CODECS = {
    VideoCodec.H264: FfmpegVideoCodec.H264,
    VideoCodec.H265: FfmpegVideoCodec.HEVC,
}


class IngestTestCase(TestCase):
    def import_settings(self, scene, **overrides):
        self.moblin.import_settings(
            overrides={
                "streams": [RECORD_STREAM_SETTINGS],
                "scenes": [scene | {"enabled": True, "overrideMic": True}],
                **overrides,
            }
        )

    def record_ingest(self, startup_delay: int = 1, number_of_ingests: int = 1) -> Path:
        recorder = Recorder(self.moblin, f"{self.name}.mp4")
        self.wait_for_ingest_stream_started(
            number_of_ingests=number_of_ingests,
            startup_delay=startup_delay,
        )
        with recorder:
            self.moblin.wait_for_ingests(
                bitrate=Range(number_of_ingests * 7_000_000, number_of_ingests * 9_000_000),
                total_bytes=number_of_ingests * 10_000_000,
                number_of_ingests=number_of_ingests,
            )
        return recorder.recording


class IngestRtmpServer(IngestTestCase):
    """Stream to an RTMP server ingest."""

    def setup(self):
        self.import_settings(
            scene={
                "cameraPosition": CameraPosition.RTMP,
                "rtmpCameraId": STREAM_ID,
                "micId": mic_id(STREAM_ID),
            },
            rtmpServer={
                "enabled": True,
                "port": RTMP_SERVER_PORT,
                "streams": [{"id": STREAM_ID, "name": "1", "streamKey": "1"}],
            },
        )
        self.moblin.wait_for_tcp_ports(RTMP_SERVER_PORT)

    def run(self):
        with FfmpegTestStream(url=self.moblin.ingest_rtmp_url(), files_dir=FILES_DIR):
            recording = self.record_ingest()
        self.assert_recording(recording, has_audio_time_codes=True)


class IngestSrtServer(IngestTestCase):
    """Stream to an SRT server ingest."""

    def setup(self):
        self.import_settings(
            scene={
                "cameraPosition": CameraPosition.SRTLA,
                "srtlaCameraId": STREAM_ID,
                "micId": mic_id(STREAM_ID),
            },
            srtlaServer={
                "enabled": True,
                "srtPort": SRT_SERVER_PORT,
                "streams": [{"id": STREAM_ID, "name": "Test", "streamId": "1"}],
            },
        )

    def run(self):
        stream = FfmpegTestStream(
            url=self.moblin.ingest_srt_url(),
            files_dir=FILES_DIR,
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
                "srtClientCameraId": STREAM_ID,
                "micId": mic_id(STREAM_ID),
            },
            srtClient={
                "streams": [
                    {
                        "id": STREAM_ID,
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
            files_dir=FILES_DIR,
            transport_format=TransportFormat.MPEGTS,
        )
        with stream:
            recording = self.record_ingest()
        self.assert_recording(recording)


class IngestRtspClient(IngestTestCase):
    """Stream to an RTSP client ingest."""

    def __init__(self, moblin: Moblin, video_codec: VideoCodec):
        super().__init__(moblin, f"IngestRtspClient{video_codec.name}")
        self._video_codec = video_codec

    def setup(self):
        self.import_settings(
            scene={
                "cameraPosition": CameraPosition.RTSP,
                "rtspCameraId": STREAM_ID,
                "micId": mic_id(STREAM_ID),
            },
            rtspClient={
                "streams": [
                    {
                        "id": STREAM_ID,
                        "name": "1",
                        "url": self.moblin.tester_rtsp_url("1"),
                        "enabled": True,
                    }
                ],
            },
        )

    def run(self):
        with MediaMtx() as mediamtx:
            stream = FfmpegTestStream(
                url=f"rtmp://localhost:{TESTER_RTMP_PORT}/1",
                files_dir=FILES_DIR,
                video_codec=FFMPEG_VIDEO_CODECS[self._video_codec],
            )
            with stream:
                mediamtx.wait_for_rtsp_stream("1", 2_000_000)
                recording = self.record_ingest()
        self.assert_recording(recording)


class IngestRistServer(IngestTestCase):
    """Stream to an RIST server ingest."""

    def setup(self):
        self.import_settings(
            scene={
                "cameraPosition": CameraPosition.RIST,
                "ristCameraId": STREAM_ID,
                "micId": mic_id(STREAM_ID),
            },
            ristServer={
                "enabled": True,
                "port": RIST_SERVER_PORT,
                "streams": [{"id": STREAM_ID, "name": "1", "virtualDestinationPort": 1}],
            },
        )

    def run(self):
        stream = FfmpegTestStream(
            url=self.moblin.ingest_rist_url(),
            files_dir=FILES_DIR,
            transport_format=TransportFormat.MPEGTS,
        )
        with stream:
            recording = self.record_ingest()
        self.assert_recording(recording)


class IngestWhipServer(IngestTestCase):
    """Stream to a WHIP server ingest."""

    def setup(self):
        self.import_settings(
            scene={
                "cameraPosition": CameraPosition.WHIP,
                "whipCameraId": STREAM_ID,
                "micId": mic_id(STREAM_ID),
            },
            whipServer={
                "enabled": True,
                "port": WHIP_SERVER_PORT,
                "streams": [
                    {
                        "id": STREAM_ID,
                        "name": "1",
                        "streamKey": "1",
                        "latency": 2000,
                    }
                ],
            },
        )

    def run(self):
        with FfmpegWhipTestStream(url=self.moblin.ingest_whip_url(), files_dir=FILES_DIR):
            recording = self.record_ingest(startup_delay=4)
        self.assert_recording(recording)


class IngestWhepClient(IngestTestCase):
    """Stream to a WHEP client ingest."""

    def setup(self):
        self.import_settings(
            scene={
                "cameraPosition": CameraPosition.WHEP,
                "whepCameraId": STREAM_ID,
                "micId": mic_id(STREAM_ID),
            },
            whepClient={
                "streams": [
                    {
                        "id": STREAM_ID,
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
            with FfmpegRtspTestStream(url=rtsp_reader_url("1"), files_dir=FILES_DIR):
                mediamtx.wait_for_rtsp_publisher("1", 2_000_000)
                recording = self.record_ingest(startup_delay=4)
        self.assert_recording(recording)


class ParallelIngestTestCase(IngestTestCase):
    def import_parallel_settings(
        self,
        camera_position: CameraPosition,
        camera_id_key: str,
        first_stream_id: str,
        second_stream_id: str,
        **overrides,
    ):
        self.import_settings(
            scene={
                "cameraPosition": camera_position,
                camera_id_key: first_stream_id,
                "micId": mic_id(first_stream_id),
                "widgets": [
                    scene_widget_settings(
                        SECOND_INGEST_WIDGET_ID,
                        x=0,
                        y=0,
                        size=50,
                        alignment=Alignment.BOTTOM_RIGHT,
                    )
                ],
            },
            widgets=[
                video_source_widget_settings(
                    "2",
                    SECOND_INGEST_WIDGET_ID,
                    {"cameraPosition": camera_position, camera_id_key: second_stream_id},
                )
            ],
            **overrides,
        )

    def record_parallel_ingests(self, startup_delay: int = 1) -> Path:
        return self.record_ingest(startup_delay=startup_delay, number_of_ingests=2)

    def assert_parallel_recording(self, recording: Path):
        self.assert_recording(recording, has_qr_codes=False)


class IngestParallelRtmpServer(ParallelIngestTestCase):
    """Stream to two RTMP server ingests in parallel."""

    def setup(self):
        self.import_parallel_settings(
            camera_position=CameraPosition.RTMP,
            camera_id_key="rtmpCameraId",
            first_stream_id=STREAM_ID,
            second_stream_id=STREAM_2_ID,
            rtmpServer={
                "enabled": True,
                "port": RTMP_SERVER_PORT,
                "streams": [
                    {"id": STREAM_ID, "name": "1", "streamKey": "1"},
                    {"id": STREAM_2_ID, "name": "2", "streamKey": "2"},
                ],
            },
        )
        self.moblin.wait_for_tcp_ports(RTMP_SERVER_PORT)

    def run(self):
        stream_1 = FfmpegTestStream(url=self.moblin.ingest_rtmp_url("1"), files_dir=FILES_DIR)
        stream_2 = FfmpegTestStream(url=self.moblin.ingest_rtmp_url("2"), files_dir=FILES_DIR)
        with stream_1, stream_2:
            recording = self.record_parallel_ingests()
        self.assert_parallel_recording(recording)


class IngestParallelSrtServer(ParallelIngestTestCase):
    """Stream to two SRT server ingests in parallel."""

    def setup(self):
        self.import_parallel_settings(
            camera_position=CameraPosition.SRTLA,
            camera_id_key="srtlaCameraId",
            first_stream_id=STREAM_ID,
            second_stream_id=STREAM_2_ID,
            srtlaServer={
                "enabled": True,
                "srtPort": SRT_SERVER_PORT,
                "streams": [
                    {"id": STREAM_ID, "name": "1", "streamId": "1"},
                    {"id": STREAM_2_ID, "name": "2", "streamId": "2"},
                ],
            },
        )

    def run(self):
        stream_1 = FfmpegTestStream(
            url=self.moblin.ingest_srt_url("1"), files_dir=FILES_DIR, transport_format=TransportFormat.MPEGTS
        )
        stream_2 = FfmpegTestStream(
            url=self.moblin.ingest_srt_url("2"), files_dir=FILES_DIR, transport_format=TransportFormat.MPEGTS
        )
        with stream_1, stream_2:
            recording = self.record_parallel_ingests()
        self.assert_parallel_recording(recording)


class IngestParallelSrtClient(ParallelIngestTestCase):
    """Stream to two SRT client ingests in parallel."""

    def setup(self):
        self.import_parallel_settings(
            camera_position=CameraPosition.SRT_CLIENT,
            camera_id_key="srtClientCameraId",
            first_stream_id=STREAM_ID,
            second_stream_id=STREAM_2_ID,
            srtClient={
                "streams": [
                    {
                        "id": STREAM_ID,
                        "name": "1",
                        "url": self.moblin.tester_srt_url(SRT_CLIENT_1_SERVER_PORT),
                        "enabled": True,
                    },
                    {
                        "id": STREAM_2_ID,
                        "name": "2",
                        "url": self.moblin.tester_srt_url(SRT_CLIENT_2_SERVER_PORT),
                        "enabled": True,
                    },
                ],
            },
        )

    def run(self):
        stream_1 = FfmpegTestStream(
            url=srt_listener_url(SRT_CLIENT_1_SERVER_PORT, stream_id="1"),
            files_dir=FILES_DIR,
            transport_format=TransportFormat.MPEGTS,
        )
        stream_2 = FfmpegTestStream(
            url=srt_listener_url(SRT_CLIENT_2_SERVER_PORT, stream_id="2"),
            files_dir=FILES_DIR,
            transport_format=TransportFormat.MPEGTS,
        )
        with stream_1, stream_2:
            recording = self.record_parallel_ingests()
        self.assert_parallel_recording(recording)


class IngestParallelRtspClient(ParallelIngestTestCase):
    """Stream to two RTSP client ingests in parallel."""

    def setup(self):
        self.import_parallel_settings(
            camera_position=CameraPosition.RTSP,
            camera_id_key="rtspCameraId",
            first_stream_id=STREAM_ID,
            second_stream_id=STREAM_2_ID,
            rtspClient={
                "streams": [
                    {
                        "id": STREAM_ID,
                        "name": "1",
                        "url": self.moblin.tester_rtsp_url("1"),
                        "enabled": True,
                    },
                    {
                        "id": STREAM_2_ID,
                        "name": "2",
                        "url": self.moblin.tester_rtsp_url("2"),
                        "enabled": True,
                    },
                ],
            },
        )

    def run(self):
        with MediaMtx() as mediamtx:
            stream_1 = FfmpegTestStream(url=f"rtmp://localhost:{TESTER_RTMP_PORT}/1", files_dir=FILES_DIR)
            stream_2 = FfmpegTestStream(url=f"rtmp://localhost:{TESTER_RTMP_PORT}/2", files_dir=FILES_DIR)
            with stream_1, stream_2:
                mediamtx.wait_for_rtsp_stream("1", 2_000_000)
                mediamtx.wait_for_rtsp_stream("2", 2_000_000)
                recording = self.record_parallel_ingests()
        self.assert_parallel_recording(recording)


class IngestParallelRistServer(ParallelIngestTestCase):
    """Stream to two RIST server ingests in parallel."""

    def setup(self):
        self.import_parallel_settings(
            camera_position=CameraPosition.RIST,
            camera_id_key="ristCameraId",
            first_stream_id=STREAM_ID,
            second_stream_id=STREAM_2_ID,
            ristServer={
                "enabled": True,
                "port": RIST_SERVER_PORT,
                "streams": [
                    {"id": STREAM_ID, "name": "1", "virtualDestinationPort": 1},
                    {"id": STREAM_2_ID, "name": "2", "virtualDestinationPort": 2},
                ],
            },
        )

    def run(self):
        stream_1 = FfmpegTestStream(
            url=self.moblin.ingest_rist_url(1), files_dir=FILES_DIR, transport_format=TransportFormat.MPEGTS
        )
        stream_2 = FfmpegTestStream(
            url=self.moblin.ingest_rist_url(2), files_dir=FILES_DIR, transport_format=TransportFormat.MPEGTS
        )
        with stream_1, stream_2:
            recording = self.record_parallel_ingests(startup_delay=3)
        self.assert_parallel_recording(recording)


class IngestParallelWhipServer(ParallelIngestTestCase):
    """Stream to two WHIP server ingests in parallel."""

    def setup(self):
        self.import_parallel_settings(
            camera_position=CameraPosition.WHIP,
            camera_id_key="whipCameraId",
            first_stream_id=STREAM_ID,
            second_stream_id=STREAM_2_ID,
            whipServer={
                "enabled": True,
                "port": WHIP_SERVER_PORT,
                "streams": [
                    {
                        "id": STREAM_ID,
                        "name": "1",
                        "streamKey": "1",
                        "latency": 2000,
                    },
                    {
                        "id": STREAM_2_ID,
                        "name": "2",
                        "streamKey": "2",
                        "latency": 2000,
                    },
                ],
            },
        )

    def run(self):
        stream_1 = FfmpegWhipTestStream(url=self.moblin.ingest_whip_url("1"), files_dir=FILES_DIR)
        stream_2 = FfmpegWhipTestStream(url=self.moblin.ingest_whip_url("2"), files_dir=FILES_DIR)
        with stream_1, stream_2:
            recording = self.record_parallel_ingests(startup_delay=3)
        self.assert_parallel_recording(recording)


class IngestParallelWhepClient(ParallelIngestTestCase):
    """Stream to two WHEP client ingests in parallel."""

    def setup(self):
        self.import_parallel_settings(
            camera_position=CameraPosition.WHEP,
            camera_id_key="whepCameraId",
            first_stream_id=STREAM_ID,
            second_stream_id=STREAM_2_ID,
            whepClient={
                "streams": [
                    {
                        "id": STREAM_ID,
                        "name": "1",
                        "url": self.moblin.tester_whep_url("1"),
                        "enabled": True,
                        "latency": 2000,
                    },
                    {
                        "id": STREAM_2_ID,
                        "name": "2",
                        "url": self.moblin.tester_whep_url("2"),
                        "enabled": True,
                        "latency": 2000,
                    },
                ],
            },
        )

    def run(self):
        with MediaMtx() as mediamtx:
            stream_1 = FfmpegRtspTestStream(url=rtsp_reader_url("1"), files_dir=FILES_DIR)
            stream_2 = FfmpegRtspTestStream(url=rtsp_reader_url("2"), files_dir=FILES_DIR)
            with stream_1, stream_2:
                mediamtx.wait_for_rtsp_publisher("1", 2_000_000)
                mediamtx.wait_for_rtsp_publisher("2", 2_000_000)
                recording = self.record_parallel_ingests(startup_delay=3)
        self.assert_parallel_recording(recording)


def tests(moblin: Moblin):
    return [
        IngestRtmpServer(moblin),
        IngestSrtServer(moblin),
        IngestSrtClient(moblin),
        IngestRtspClient(moblin, VideoCodec.H264),
        IngestRtspClient(moblin, VideoCodec.H265),
        IngestRistServer(moblin),
        IngestWhipServer(moblin),
        IngestWhepClient(moblin),
        IngestParallelRtmpServer(moblin),
        IngestParallelSrtServer(moblin),
        IngestParallelSrtClient(moblin),
        IngestParallelRtspClient(moblin),
        IngestParallelRistServer(moblin),
        IngestParallelWhipServer(moblin),
        IngestParallelWhepClient(moblin),
    ]
