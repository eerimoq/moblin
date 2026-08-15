import logging
import time
from contextlib import ExitStack
from dataclasses import dataclass
from enum import StrEnum
from pathlib import Path

from utils.config import RIST_SERVER_PORT
from utils.config import RTMP_SERVER_PORT
from utils.config import SRT_SERVER_PORT
from utils.config import TESTER_SRT_PORT
from utils.config import TESTER_WEBRTC_PORT
from utils.config import TESTER_WEBRTC_UDP_PORT
from utils.config import Config
from utils.config import rtsp_reader_url
from utils.config import srt_listener_url
from utils.ffmpeg import FfmpegCommand
from utils.ffmpeg import FfmpegRtspTestStream
from utils.ffmpeg import FfmpegTestStream
from utils.ffmpeg import StreamRecorder
from utils.ffmpeg import TransportFormat
from utils.ffmpeg import ffprobe_audio
from utils.generate_device_settings import Alignment
from utils.generate_device_settings import BitrateRateControl
from utils.generate_device_settings import CameraPosition
from utils.generate_device_settings import Resolution
from utils.generate_device_settings import SceneName
from utils.generate_device_settings import scene_widget_settings
from utils.generate_device_settings import text_widget_settings
from utils.generate_device_settings import uuid
from utils.generate_device_settings import video_source_widget_settings
from utils.mediamtx import MediaMtx
from utils.moblin import Moblin
from utils.monitor import Monitor
from utils.test_case import TestCase
from utils.traffic_shaper import Group
from utils.traffic_shaper import Profile
from utils.traffic_shaper import ProfileName
from utils.traffic_shaper import Protocol
from utils.traffic_shaper import Relay
from utils.traffic_shaper import Side
from utils.traffic_shaper import TrafficShaper
from utils.traffic_shaper import parse_profile
from utils.utils import FILES_DIR
from utils.utils import Range
from utils.utils import manual_validation
from utils.utils import wait_until

LOGGER = logging.getLogger(__name__)


class Ingest(StrEnum):
    RTMP = "rtmp"
    SRT = "srt"
    RIST = "rist"
    WHEP = "whep"

    def label(self) -> str:
        return self.name


WHEP_PATH = "stabilitywhep"
STREAM_PATH = "stability"
INGEST_BITRATE = 5_000_000
STREAM_BITRATE = 5_000_000
STREAM_BITRATE_RANGE = Range(4_000_000, 6_500_000)
INGEST_BITRATE_RANGE = Range(4_250_000, 6_500_000)
STREAM_FPS = 30
STREAM_RESOLUTION = Resolution.FULL_HD
STREAM_WIDTH, STREAM_HEIGHT = STREAM_RESOLUTION.size()
STREAM_FILE = FILES_DIR / f"{STREAM_PATH}-stream.ts"
RECORDING_FILE_NAME = f"{STREAM_PATH}-recording.mp4"
INGEST_WIDGET_SIZE = 33
NAME_WIDGET_WIDTH = 150
NAME_WIDGET_FONT_SIZE = 40
NAME_WIDGET_X = INGEST_WIDGET_SIZE / 2 - 100 * (NAME_WIDGET_WIDTH / 2) / STREAM_WIDTH
NAME_WIDGET_BOTTOM_ROW_Y = 100 - INGEST_WIDGET_SIZE
RELAYS = [
    Relay(Group.STREAM, Protocol.UDP, TESTER_SRT_PORT, Side.TESTER),
    Relay(Group.INGESTS, Protocol.TCP, RTMP_SERVER_PORT, Side.DEVICE),
    Relay(Group.INGESTS, Protocol.UDP, SRT_SERVER_PORT, Side.DEVICE),
    Relay(Group.INGESTS, Protocol.UDP, RIST_SERVER_PORT, Side.DEVICE),
    Relay(Group.INGESTS, Protocol.TCP, TESTER_WEBRTC_PORT, Side.TESTER),
    Relay(Group.INGESTS, Protocol.UDP, TESTER_WEBRTC_UDP_PORT, Side.TESTER),
]
RTMP_STREAM_ID = uuid()
SRT_STREAM_ID = uuid()
RIST_STREAM_ID = uuid()
WHEP_STREAM_ID = uuid()
RTMP_WIDGET_ID = uuid()
SRT_WIDGET_ID = uuid()
RIST_WIDGET_ID = uuid()
WHEP_WIDGET_ID = uuid()
RTMP_NAME_WIDGET_ID = uuid()
SRT_NAME_WIDGET_ID = uuid()
RIST_NAME_WIDGET_ID = uuid()
WHEP_NAME_WIDGET_ID = uuid()


@dataclass
class Source:
    name: str
    command: FfmpegCommand


class StabilityIngestsOneStream(TestCase):
    """Test long streaming sessions."""

    def __init__(
        self,
        moblin: Moblin,
        ingests: list[Ingest],
        stream: bool,
        record: bool,
        duration: float,
        shaper: TrafficShaper | None,
    ):
        super().__init__(moblin)
        self._ingests = ingests
        self._stream = stream
        self._record = record
        self._recording_started = False
        self._duration = duration
        self._shaper = shaper
        self._monitor: Monitor | None = None
        self._stream_profile: Profile | None = None
        self._ingests_profile: Profile | None = None
        self._stream_bitrate_range = STREAM_BITRATE_RANGE
        self._ingests_bitrate_range = ingests_bitrate_range(len(ingests))

    def setup(self):
        if self._shaper is not None:
            self.moblin.use_media_relay(self._shaper.ip_address)
            self._update_expectations(self._shaper)
        self.moblin.import_settings(
            overrides={
                "streams": [
                    {
                        "name": "Stability",
                        "enabled": True,
                        "url": self.moblin.tester_srt_publish_url(STREAM_PATH),
                        "srt": {"adaptiveBitrateEnabled": self._stream_profile is not None},
                        "bitrateRateControl": BitrateRateControl.CBR,
                        "bitrate": STREAM_BITRATE,
                        "fps": STREAM_FPS,
                        "resolution": STREAM_RESOLUTION,
                    }
                ],
                "scenes": [
                    scene_settings(SceneName.FRONT, CameraPosition.FRONT),
                    scene_settings(SceneName.BACK, CameraPosition.BACK),
                ],
                "widgets": [
                    video_source_widget_settings(
                        "RTMP",
                        RTMP_WIDGET_ID,
                        {
                            "cameraPosition": CameraPosition.RTMP,
                            "rtmpCameraId": RTMP_STREAM_ID,
                        },
                    ),
                    video_source_widget_settings(
                        "SRT",
                        SRT_WIDGET_ID,
                        {
                            "cameraPosition": CameraPosition.SRTLA,
                            "srtlaCameraId": SRT_STREAM_ID,
                        },
                    ),
                    video_source_widget_settings(
                        "RIST",
                        RIST_WIDGET_ID,
                        {
                            "cameraPosition": CameraPosition.RIST,
                            "ristCameraId": RIST_STREAM_ID,
                        },
                    ),
                    video_source_widget_settings(
                        "WHEP",
                        WHEP_WIDGET_ID,
                        {
                            "cameraPosition": CameraPosition.WHEP,
                            "whepCameraId": WHEP_STREAM_ID,
                        },
                    ),
                    name_widget_settings("RTMP", RTMP_NAME_WIDGET_ID),
                    name_widget_settings("SRT", SRT_NAME_WIDGET_ID),
                    name_widget_settings("RIST", RIST_NAME_WIDGET_ID),
                    name_widget_settings("WHEP", WHEP_NAME_WIDGET_ID),
                ],
                "rtmpServer": {
                    "enabled": Ingest.RTMP in self._ingests,
                    "port": RTMP_SERVER_PORT,
                    "streams": [{"id": RTMP_STREAM_ID, "name": "1", "streamKey": "1"}],
                },
                "srtlaServer": {
                    "enabled": Ingest.SRT in self._ingests,
                    "srtPort": SRT_SERVER_PORT,
                    "streams": [{"id": SRT_STREAM_ID, "name": "1", "streamId": "1"}],
                },
                "ristServer": {
                    "enabled": Ingest.RIST in self._ingests,
                    "port": RIST_SERVER_PORT,
                    "streams": [{"id": RIST_STREAM_ID, "name": "1", "virtualDestinationPort": 1}],
                },
                "whepClient": {
                    "streams": [
                        {
                            "id": WHEP_STREAM_ID,
                            "name": "1",
                            "url": self.moblin.tester_whep_url(WHEP_PATH),
                            "enabled": Ingest.WHEP in self._ingests,
                            "latency": 2000,
                        }
                    ],
                },
            }
        )
        time.sleep(5)

    def run(self):
        manual_validation(
            LOGGER,
            "Keep the device connected to power with the app in the foreground",
        )
        recorder: StreamRecorder | None = None
        recording: Path | None = None
        with ExitStack() as stack:
            webrtc_host = None
            if self._shaper is not None:
                stack.enter_context(self._shaper)
                webrtc_host = self._shaper.ip_address
            mediamtx = stack.enter_context(MediaMtx(log_level="warn", webrtc_host=webrtc_host, srt=False))
            if self._stream:
                recorder = stack.enter_context(StreamRecorder(srt_listener_url(), STREAM_FILE))
            sources = self._create_sources()
            for source in sources:
                stack.enter_context(source.command)
            if Ingest.WHEP in self._ingests:
                mediamtx.wait_for_rtsp_publisher(WHEP_PATH, 1_000_000)
            self._wait_for_ingests()
            if recorder is not None:
                self._go_live(recorder)
            if self._record:
                self.moblin.start_recording()
                self._recording_started = True
            self._monitor = self._create_monitor(recorder, sources)
            self._monitor_until_done(self._monitor, recorder, sources)
            if recorder is not None:
                self.moblin.end()
            if self._recording_started:
                self.moblin.stop_recording()
                recording = self._download_recording()
        self._assert_no_audio_gaps(recorder, recording)

    def teardown(self):
        if self._monitor is not None:
            self._monitor.report()
        try:
            super().teardown()
        except Exception as error:
            LOGGER.warning("Failed to stop the app. Did it crash? %s", error)

    def _download_recording(self) -> Path | None:
        LOGGER.debug("Downloading the recording...")
        try:
            recording = self.moblin.download_and_delete_latest_recording(RECORDING_FILE_NAME)
        except Exception as error:
            LOGGER.warning("Failed to download the recording. %s", error)
            return None
        LOGGER.info(
            "Downloaded the recording to %s (%.1f GB).",
            recording,
            recording.stat().st_size / 1e9,
        )
        return recording

    def _assert_no_audio_gaps(self, recorder: StreamRecorder | None, recording: Path | None):
        files = []
        if recording is not None:
            files.append(recording)
        if recorder is not None:
            files += recorder.files
        for file in files:
            self._assert_audio_presentation_time_stamps(file, ffprobe_audio(file))

    def _create_sources(self) -> list[Source]:
        return [
            Source(name=ingest.label(), command=self._create_source_command(ingest))
            for ingest in self._ingests
        ]

    def _create_source_command(self, ingest: Ingest) -> FfmpegCommand:
        match ingest:
            case Ingest.RTMP:
                return FfmpegTestStream(
                    url=self.moblin.ingest_rtmp_url(),
                    video_bitrate=INGEST_BITRATE,
                    loop_audio=True,
                    quiet=True,
                )
            case Ingest.SRT:
                return FfmpegTestStream(
                    url=self.moblin.ingest_srt_url(),
                    video_bitrate=INGEST_BITRATE,
                    loop_audio=True,
                    quiet=True,
                    transport_format=TransportFormat.MPEGTS,
                )
            case Ingest.RIST:
                return FfmpegTestStream(
                    url=self.moblin.ingest_rist_url(),
                    video_bitrate=INGEST_BITRATE,
                    loop_audio=True,
                    quiet=True,
                    transport_format=TransportFormat.MPEGTS,
                )
            case Ingest.WHEP:
                return FfmpegRtspTestStream(
                    url=rtsp_reader_url(WHEP_PATH),
                    video_bitrate=INGEST_BITRATE,
                    loop_audio=True,
                    quiet=True,
                )

    def _update_expectations(self, shaper: TrafficShaper):
        self._stream_profile = shaper.profile(Group.STREAM)
        self._ingests_profile = shaper.profile(Group.INGESTS)
        self._stream_bitrate_range = shaped_bitrate_range(
            STREAM_BITRATE, self._stream_profile, STREAM_BITRATE_RANGE
        )
        self._ingests_bitrate_range = shaped_bitrate_range(
            len(self._ingests) * INGEST_BITRATE,
            self._ingests_profile,
            ingests_bitrate_range(len(self._ingests)),
        )

    def _wait_for_ingests(self):
        if len(self._ingests) == 0:
            return
        self.moblin.wait_for_ingests(
            self._ingests_bitrate_range,
            total_bytes=0,
            number_of_ingests=len(self._ingests),
        )

    def _go_live(self, recorder: StreamRecorder):
        self.moblin.go_live()
        self.moblin.wait_for_bitrate(
            self._stream_bitrate_range.minimum,
            self._stream_bitrate_range.maximum,
            None,
            3_000_000,
        )
        wait_until(lambda: recorder.total_bytes() > 3_000_000, "the stream to be recorded to disk")

    def _create_monitor(self, recorder: StreamRecorder | None, sources: list[Source]) -> Monitor:
        return Monitor(
            moblin=self.moblin,
            recorder=recorder,
            source_names=[source.name for source in sources],
            number_of_ingests=len(self._ingests),
            stream_enabled=self._stream,
            stream_bitrate_range=self._stream_bitrate_range,
            ingests_bitrate_range=self._ingests_bitrate_range,
            traffic_shaping="none" if self._shaper is None else self._shaper.description(),
        )

    def _monitor_until_done(
        self,
        monitor: Monitor,
        recorder: StreamRecorder | None,
        sources: list[Source],
    ):
        end_time = time.monotonic() + self._duration
        while time.monotonic() < end_time:
            time.sleep(5)
            self.moblin.set_scene(SceneName.BACK)
            time.sleep(5)
            self.moblin.set_scene(SceneName.FRONT)
            if self._shaper is not None:
                self._shaper.poll()
            monitor.poll()
            restart_dead_sources(monitor, sources)
            if recorder is not None:
                recorder.poll()


def ingests_bitrate_range(number_of_ingests: int) -> Range:
    return Range(
        number_of_ingests * INGEST_BITRATE_RANGE.minimum,
        number_of_ingests * INGEST_BITRATE_RANGE.maximum,
    )


def scene_settings(name: SceneName, camera_position: CameraPosition):
    return {
        "name": name,
        "enabled": True,
        "cameraPosition": camera_position,
        "widgets": [
            scene_widget_settings(
                RTMP_WIDGET_ID,
                x=0,
                y=0,
                size=INGEST_WIDGET_SIZE,
                alignment=Alignment.TOP_LEFT,
            ),
            scene_widget_settings(
                SRT_WIDGET_ID,
                x=0,
                y=0,
                size=INGEST_WIDGET_SIZE,
                alignment=Alignment.TOP_RIGHT,
            ),
            scene_widget_settings(
                RIST_WIDGET_ID,
                x=0,
                y=0,
                size=INGEST_WIDGET_SIZE,
                alignment=Alignment.BOTTOM_LEFT,
            ),
            scene_widget_settings(
                WHEP_WIDGET_ID,
                x=0,
                y=0,
                size=INGEST_WIDGET_SIZE,
                alignment=Alignment.BOTTOM_RIGHT,
            ),
            name_scene_widget_settings(
                RTMP_NAME_WIDGET_ID,
                x=NAME_WIDGET_X,
                y=0,
                alignment=Alignment.TOP_LEFT,
            ),
            name_scene_widget_settings(
                SRT_NAME_WIDGET_ID,
                x=NAME_WIDGET_X,
                y=0,
                alignment=Alignment.TOP_RIGHT,
            ),
            name_scene_widget_settings(
                RIST_NAME_WIDGET_ID,
                x=NAME_WIDGET_X,
                y=NAME_WIDGET_BOTTOM_ROW_Y,
                alignment=Alignment.TOP_LEFT,
            ),
            name_scene_widget_settings(
                WHEP_NAME_WIDGET_ID,
                x=NAME_WIDGET_X,
                y=NAME_WIDGET_BOTTOM_ROW_Y,
                alignment=Alignment.TOP_RIGHT,
            ),
        ],
    }


def name_widget_settings(name: str, widget_id: str):
    return text_widget_settings(
        f"{name} name",
        widget_id,
        {
            "formatString": name,
            "fontSize": NAME_WIDGET_FONT_SIZE,
            "horizontalAlignment": "Center",
            "widthEnabled": True,
            "width": NAME_WIDGET_WIDTH,
        },
    )


def name_scene_widget_settings(widget_id: str, x: float, y: float, alignment: Alignment):
    return scene_widget_settings(widget_id, x=x, y=y, size=100, alignment=alignment)


def restart_dead_sources(monitor: Monitor, sources: list[Source]):
    for source in sources:
        if not source.command.is_running():
            monitor.source_restarted(source.name)
            source.command.restart()


def shaped_bitrate_range(
    nominal_bitrate: float,
    profile: Profile | None,
    default_range: Range,
) -> Range:
    if profile is None:
        return default_range
    minimum_rate = profile.minimum_rate()
    maximum_rate = profile.maximum_rate()
    if minimum_rate is None or maximum_rate is None:
        return default_range
    return Range(
        0.2 * min(nominal_bitrate, minimum_rate),
        1.3 * min(nominal_bitrate, maximum_rate),
    )


def create_traffic_shaper(
    config: Config,
    stream_traffic_shaping_profile: ProfileName | None,
    stream_traffic_shaping_parameters: str | None,
    ingests_traffic_shaping_profile: ProfileName | None,
    ingests_traffic_shaping_parameters: str | None,
) -> TrafficShaper | None:
    profiles: dict[Group, Profile] = {}
    if stream_traffic_shaping_profile is not None:
        profiles[Group.STREAM] = parse_profile(
            stream_traffic_shaping_profile, stream_traffic_shaping_parameters
        )
    if ingests_traffic_shaping_profile is not None:
        profiles[Group.INGESTS] = parse_profile(
            ingests_traffic_shaping_profile, ingests_traffic_shaping_parameters
        )
    if len(profiles) == 0:
        return None
    return TrafficShaper(config, RELAYS, profiles)


def tests(
    moblin: Moblin,
    ingests: list[Ingest],
    stream: bool,
    record: bool,
    duration: float,
    shaper: TrafficShaper | None,
):
    return [
        StabilityIngestsOneStream(moblin, ingests, stream, record, duration, shaper),
    ]
