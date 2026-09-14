import logging
import subprocess
from array import array
from pathlib import Path

from systest_moblin.ffmpeg import FFMPEG_COMMAND
from systest_moblin.ffmpeg import FfmpegCommand
from systest_moblin.ffmpeg import FfmpegRtspTestStream
from systest_moblin.ffmpeg import FfmpegTestStream
from systest_moblin.ffmpeg import FfmpegVideoCodec
from systest_moblin.ffmpeg import FfmpegWhipTestStream
from systest_moblin.ffmpeg import TransportFormat
from systest_moblin.ffmpeg import measure_audio_band_levels
from systest_moblin.ffmpeg import measure_max_volume
from systest_moblin.ffmpeg import video_encoder_args

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

LOGGER = logging.getLogger(__name__)
STREAM_ID = uuid()
STREAM_2_ID = uuid()
SECOND_INGEST_WIDGET_ID = uuid()
LOUD_DURATION = 7
LOUD_LEVEL_DB = -12
LEVEL_WINDOW = 0.25
FFMPEG_VIDEO_CODECS = {
    VideoCodec.H264: FfmpegVideoCodec.H264,
    VideoCodec.H265: FfmpegVideoCodec.HEVC,
}


class FfmpegLoudThenSilentTestStream(FfmpegCommand):
    def __init__(self, url: str) -> None:
        super().__init__()
        self._url = url

    def args(self) -> list[str]:
        return [
            "-re",
            "-f",
            "lavfi",
            "-i",
            "testsrc2=size=1920x1080:rate=30",
            "-re",
            "-f",
            "lavfi",
            "-i",
            f"aevalsrc=exprs='if(lt(t,{LOUD_DURATION}),sin(2*PI*1000*t),0)':s=48000",
            *video_encoder_args(8_000_000, FfmpegVideoCodec.H264, True),
            "-pix_fmt",
            "yuv420p",
            "-g",
            "60",
            "-keyint_min",
            "60",
            "-c:a",
            "aac",
            "-b:a",
            "128k",
            "-ar",
            "48000",
            "-ac",
            "1",
            "-vf",
            "qrencode=text=n %{frame_num} pts %{pts}:q=400:x=150,"
            "drawtext=fontsize=60:text=%{frame_num}:x=10:y=100",
            "-f",
            TransportFormat.FLV,
            self._url,
        ]


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
        self.assert_recording(recording, FILES_DIR, has_audio_time_codes=True)


class IngestRtmpServerLoudThenSilent(IngestRtmpServer):
    """Stream to an RTMP server ingest with maximum audio volume for a few seconds and then
    silence for a few seconds. Validate that the audio level reported by the remote control is
    the peak of the loud audio and then the silence level, and that the recording is loud and
    then that all audio samples are exactly zero.

    """

    def run(self):
        recorder = Recorder(self.moblin, f"{self.name}.mp4")
        with FfmpegLoudThenSilentTestStream(url=self.moblin.ingest_rtmp_url()):
            self.wait_for_ingest_stream_started()
            with recorder:
                self._assert_loud_audio_level()
                self._assert_silent_audio_level()
                self.moblin.wait_for_ingests(
                    bitrate=Range(7_000_000, 9_000_000),
                    total_bytes=4_000_000,
                    number_of_ingests=1,
                )
        self._assert_loud_then_silent(recorder.recording)

    def _assert_loud_audio_level(self):
        self.moblin.wait_for_audio_level(lambda level: level > -30, "loud audio level")
        level = self._get_audio_level()
        self.assert_greater(level, -3, "Loud audio level.")
        self.assert_less(level, 1, "Loud audio level.")

    def _assert_silent_audio_level(self):
        self.moblin.wait_for_audio_level(lambda level: level < -30, "silent audio level")
        self.assert_equal(self._get_audio_level(), -160, "Silent audio level.")

    def _get_audio_level(self) -> float:
        level = self.moblin.get_audio_level()
        message = self.moblin.get_audio_level_message()
        LOGGER.debug("Remote control audio level %.1f dB shown as '%s'.", level, message)
        self.assert_equal(message, f"{int(level)} dB, 1 ch")
        return level

    def _assert_loud_then_silent(self, recording: Path):
        samples = _read_audio_samples(recording)
        silence_start = _find_silence_start(samples)
        duration = len(samples) / 48000
        LOGGER.debug("All audio samples are zero from %.3f to %.3f s.", silence_start, duration)
        self.assert_greater(duration - silence_start, 2, "The silent part is too short.")
        self.assert_recording(recording, FILES_DIR, audio_bitrate_tolerance=80_000)
        max_volume_db = measure_max_volume(recording)
        LOGGER.debug("Max volume: %.1f dB", max_volume_db)
        self.assert_greater(max_volume_db, -1, "The loud part is attenuated.")
        loud = [
            level
            for level in measure_audio_band_levels(recording, [], LEVEL_WINDOW)
            if level.time + LEVEL_WINDOW <= silence_start
        ]
        for level in loud:
            LOGGER.debug("Audio level at %.2f s: %.1f dB", level.time, level.level)
            self.assert_greater(level.level, LOUD_LEVEL_DB, f"Audio level at {level.time:.2f} s.")
        self.assert_greater(len(loud) * LEVEL_WINDOW, 2, "The loud part is too short.")


def _read_audio_samples(recording: Path) -> array:
    output = subprocess.run(
        [*FFMPEG_COMMAND, "-loglevel", "error", "-i", str(recording), "-vn", "-f", "f32le", "-"],
        check=True,
        capture_output=True,
    ).stdout
    samples = array("f")
    samples.frombytes(output)
    return samples


def _find_silence_start(samples: array) -> float:
    last_non_zero = next((index for index in range(len(samples) - 1, -1, -1) if samples[index] != 0), -1)
    return (last_non_zero + 1) / 48000


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
        self.assert_recording(recording, FILES_DIR)


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
        self.assert_recording(recording, FILES_DIR)


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
        self.assert_recording(recording, FILES_DIR)


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
        self.assert_recording(recording, FILES_DIR)


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
        self.assert_recording(recording, FILES_DIR)


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
        self.assert_recording(recording, FILES_DIR)


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
        self.assert_recording(recording, FILES_DIR, has_qr_codes=False)


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
        IngestRtmpServerLoudThenSilent(moblin),
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
