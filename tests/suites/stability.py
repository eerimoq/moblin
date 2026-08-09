import logging
import time
from contextlib import ExitStack
from dataclasses import dataclass
from dataclasses import replace

from utils.config import RIST_SERVER_PORT
from utils.config import RTMP_SERVER_PORT
from utils.config import SRT_SERVER_PORT
from utils.config import TESTER_RTSP_PORT
from utils.config import TESTER_SRT_PORT
from utils.config import TESTER_WEBRTC_PORT
from utils.config import TESTER_WEBRTC_UDP_PORT
from utils.config import Config
from utils.config import srt_reader_url
from utils.ffmpeg import FfmpegCommand
from utils.ffmpeg import FfmpegRtspTestStream
from utils.ffmpeg import FfmpegTestStream
from utils.generate_device_settings import scene_widget_settings
from utils.generate_device_settings import text_widget_settings
from utils.generate_device_settings import uuid
from utils.generate_device_settings import video_source_widget_settings
from utils.mediamtx import MediaMtx
from utils.moblin import Moblin
from utils.monitor import DEVIATION_TIMEOUT
from utils.monitor import Monitor
from utils.monitor import StreamContentExpectation
from utils.test_case import TestCase
from utils.traffic_shaper import DEVICE_SIDE
from utils.traffic_shaper import INGESTS_GROUP
from utils.traffic_shaper import STREAM_GROUP
from utils.traffic_shaper import TCP
from utils.traffic_shaper import TESTER_SIDE
from utils.traffic_shaper import UDP
from utils.traffic_shaper import Profile
from utils.traffic_shaper import Relay
from utils.traffic_shaper import TrafficShaper
from utils.traffic_shaper import parse_profile
from utils.utils import FILES_DIR
from utils.utils import manual_validation

LOGGER = logging.getLogger(__name__)
DEFAULT_DURATION = 12 * 3600
POLL_INTERVAL = 10
LOG_INTERVAL = 60
STARTUP_POLL_INTERVAL = 5
INGESTS_CONNECT_TIMEOUT = 180
WHEP_PATH = "stabilitywhep"
STREAM_PATH = "stability"
NUMBER_OF_INGESTS = 4
INGEST_BITRATE = 5_000_000
STREAM_BITRATE = 5_000_000
STREAM_BITRATE_RANGE = (4_000_000, 6_500_000)
INGESTS_BITRATE_RANGE = (17_000_000, 26_000_000)
STREAM_WIDTH = 1920
STREAM_HEIGHT = 1080
STREAM_FPS = 30
STREAM_RESOLUTION = f"{STREAM_WIDTH}x{STREAM_HEIGHT}"
STREAM_CONTENT_FILE = FILES_DIR / f"{STREAM_PATH}-stream-content.ts"
INGEST_WIDGET_SIZE = 33
NAME_WIDGET_WIDTH = 150
NAME_WIDGET_FONT_SIZE = 40
NAME_WIDGET_X = INGEST_WIDGET_SIZE / 2 - 100 * (NAME_WIDGET_WIDTH / 2) / STREAM_WIDTH
NAME_WIDGET_BOTTOM_ROW_Y = 100 - INGEST_WIDGET_SIZE
SHAPED_BITRATE_MINIMUM_FACTOR = 0.2
SHAPED_BITRATE_MAXIMUM_FACTOR = 1.3
SHAPED_DEVIATION_TIMEOUT_FACTOR = 2
SHAPED_STREAM_CONTENT_MINIMUM_FPS_RATIO = 0.3
SHAPED_STREAM_CONTENT_MINIMUM_UNIQUE_VIDEO_FRAMES_RATIO = 0.3
RELAYS = [
    Relay(STREAM_GROUP, UDP, TESTER_SRT_PORT, TESTER_SIDE),
    Relay(INGESTS_GROUP, TCP, RTMP_SERVER_PORT, DEVICE_SIDE),
    Relay(INGESTS_GROUP, UDP, SRT_SERVER_PORT, DEVICE_SIDE),
    Relay(INGESTS_GROUP, UDP, RIST_SERVER_PORT, DEVICE_SIDE),
    Relay(INGESTS_GROUP, TCP, TESTER_WEBRTC_PORT, TESTER_SIDE),
    Relay(INGESTS_GROUP, UDP, TESTER_WEBRTC_UDP_PORT, TESTER_SIDE),
]
RTMP_STREAM_ID = uuid()
SRT_STREAM_ID = uuid()
RIST_STREAM_ID = uuid()
WHEP_STREAM_ID = uuid()
SRT_WIDGET_ID = uuid()
RIST_WIDGET_ID = uuid()
WHEP_WIDGET_ID = uuid()
RTMP_NAME_WIDGET_ID = uuid()
SRT_NAME_WIDGET_ID = uuid()
RIST_NAME_WIDGET_ID = uuid()
WHEP_NAME_WIDGET_ID = uuid()


class StabilityFourIngestsOneStream(TestCase):
    """Four ingests (RTMP, SRT, RIST and WHEP) and one outgoing SRT stream, all roughly
    5 Mbps, active at the same time for 12 hours, or until the app crashes.

    Bitrates, reconnections, ingests, CPU load, memory usage, thermal state and battery
    level are monitored continuously. A few seconds of the stream are read back from
    MediaMTX periodically to verify that it contains moving video and audible
    audio. The network can be shaped to simulate bad networks, with separate
    impairments for the outgoing stream and the ingests.

    """

    def __init__(
        self,
        moblin: Moblin,
        duration: float = DEFAULT_DURATION,
        shaper: TrafficShaper | None = None,
    ):
        super().__init__(moblin)
        self._duration = duration
        self._shaper = shaper
        self._monitor: Monitor | None = None
        self._stream_profile: Profile | None = None
        self._ingests_profile: Profile | None = None
        self._stream_bitrate_range = STREAM_BITRATE_RANGE
        self._ingests_bitrate_range = INGESTS_BITRATE_RANGE
        self._deviation_timeout = DEVIATION_TIMEOUT

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
                        "srt": {
                            "adaptiveBitrateEnabled": self._stream_profile is not None
                        },
                        "bitrateRateControl": "CBR",
                        "bitrate": STREAM_BITRATE,
                        "fps": STREAM_FPS,
                        "resolution": STREAM_RESOLUTION,
                    }
                ],
                "scenes": [
                    {
                        "enabled": True,
                        "overrideMic": True,
                        "cameraPosition": "RTMP",
                        "rtmpCameraId": RTMP_STREAM_ID,
                        "micId": f"{RTMP_STREAM_ID} 0",
                        "widgets": [
                            scene_widget_settings(
                                SRT_WIDGET_ID,
                                x=0,
                                y=0,
                                size=INGEST_WIDGET_SIZE,
                                alignment="TopRight",
                            ),
                            scene_widget_settings(
                                RIST_WIDGET_ID,
                                x=0,
                                y=0,
                                size=INGEST_WIDGET_SIZE,
                                alignment="BottomLeft",
                            ),
                            scene_widget_settings(
                                WHEP_WIDGET_ID,
                                x=0,
                                y=0,
                                size=INGEST_WIDGET_SIZE,
                                alignment="BottomRight",
                            ),
                            name_scene_widget_settings(
                                RTMP_NAME_WIDGET_ID, x=0, y=0, alignment="TopCenter"
                            ),
                            name_scene_widget_settings(
                                SRT_NAME_WIDGET_ID,
                                x=NAME_WIDGET_X,
                                y=0,
                                alignment="TopRight",
                            ),
                            name_scene_widget_settings(
                                RIST_NAME_WIDGET_ID,
                                x=NAME_WIDGET_X,
                                y=NAME_WIDGET_BOTTOM_ROW_Y,
                                alignment="TopLeft",
                            ),
                            name_scene_widget_settings(
                                WHEP_NAME_WIDGET_ID,
                                x=NAME_WIDGET_X,
                                y=NAME_WIDGET_BOTTOM_ROW_Y,
                                alignment="TopRight",
                            ),
                        ],
                    }
                ],
                "widgets": [
                    video_source_widget_settings(
                        "SRT",
                        SRT_WIDGET_ID,
                        {"cameraPosition": "SRT(LA)", "srtlaCameraId": SRT_STREAM_ID},
                    ),
                    video_source_widget_settings(
                        "RIST",
                        RIST_WIDGET_ID,
                        {"cameraPosition": "RIST", "ristCameraId": RIST_STREAM_ID},
                    ),
                    video_source_widget_settings(
                        "WHEP",
                        WHEP_WIDGET_ID,
                        {"cameraPosition": "WHEP", "whepCameraId": WHEP_STREAM_ID},
                    ),
                    name_widget_settings("RTMP", RTMP_NAME_WIDGET_ID),
                    name_widget_settings("SRT", SRT_NAME_WIDGET_ID),
                    name_widget_settings("RIST", RIST_NAME_WIDGET_ID),
                    name_widget_settings("WHEP", WHEP_NAME_WIDGET_ID),
                ],
                "rtmpServer": {
                    "enabled": True,
                    "port": RTMP_SERVER_PORT,
                    "streams": [{"id": RTMP_STREAM_ID, "name": "1", "streamKey": "1"}],
                },
                "srtlaServer": {
                    "enabled": True,
                    "srtPort": SRT_SERVER_PORT,
                    "streams": [{"id": SRT_STREAM_ID, "name": "1", "streamId": "1"}],
                },
                "ristServer": {
                    "enabled": True,
                    "port": RIST_SERVER_PORT,
                    "streams": [
                        {"id": RIST_STREAM_ID, "name": "1", "virtualDestinationPort": 1}
                    ],
                },
                "whepClient": {
                    "streams": [
                        {
                            "id": WHEP_STREAM_ID,
                            "name": "1",
                            "url": self.moblin.tester_whep_url(WHEP_PATH),
                            "enabled": True,
                            "latency": 2000,
                        }
                    ],
                },
            }
        )
        time.sleep(STARTUP_POLL_INTERVAL)

    def run(self):
        manual_validation(
            LOGGER,
            "Keep the device connected to power with the app in the foreground",
        )
        with ExitStack() as stack:
            webrtc_host = None
            if self._shaper is not None:
                stack.enter_context(self._shaper)
                webrtc_host = self._shaper.ip_address
            mediamtx = stack.enter_context(
                MediaMtx(log_level="warn", webrtc_host=webrtc_host)
            )
            sources = self._create_sources()
            for source in sources:
                stack.enter_context(source.command)
            mediamtx.wait_for_rtsp_publisher(WHEP_PATH, 1_000_000)
            self._go_live(mediamtx)
            self._monitor = self._create_monitor(mediamtx, sources)
            self._monitor_until_done(self._monitor, sources)

    def teardown(self):
        if self._monitor is not None:
            self._monitor.report()
        try:
            super().teardown()
        except Exception as error:
            LOGGER.warning("Failed to stop the app. Did it crash? %s", error)

    def _create_sources(self) -> list[Source]:
        return [
            Source(
                name="RTMP",
                command=self._create_source(
                    FfmpegTestStream, self.moblin.ingest_rtmp_url()
                ),
            ),
            Source(
                name="SRT",
                command=self._create_source(
                    FfmpegTestStream,
                    self.moblin.ingest_srt_url(),
                    transport_format="mpegts",
                ),
            ),
            Source(
                name="RIST",
                command=self._create_source(
                    FfmpegTestStream,
                    self.moblin.ingest_rist_url(),
                    transport_format="mpegts",
                ),
            ),
            Source(
                name="WHEP",
                command=self._create_source(
                    FfmpegRtspTestStream,
                    f"rtsp://localhost:{TESTER_RTSP_PORT}/{WHEP_PATH}",
                ),
            ),
        ]

    def _create_source(self, factory, url: str, **kwargs) -> FfmpegCommand:
        return factory(
            url=url,
            video_bitrate=INGEST_BITRATE,
            loop_audio=True,
            quiet=True,
            **kwargs,
        )

    def _update_expectations(self, shaper: TrafficShaper):
        self._stream_profile = shaper.profile(STREAM_GROUP)
        self._ingests_profile = shaper.profile(INGESTS_GROUP)
        self._stream_bitrate_range = shaped_bitrate_range(
            STREAM_BITRATE, self._stream_profile, STREAM_BITRATE_RANGE
        )
        self._ingests_bitrate_range = shaped_bitrate_range(
            NUMBER_OF_INGESTS * INGEST_BITRATE,
            self._ingests_profile,
            INGESTS_BITRATE_RANGE,
        )
        self._deviation_timeout = max(
            DEVIATION_TIMEOUT,
            SHAPED_DEVIATION_TIMEOUT_FACTOR * shaper.change_period(),
        )

    def _go_live(self, mediamtx: MediaMtx):
        self.moblin.wait_for_ingests(
            *self._ingests_bitrate_range,
            total_bytes=0,
            number_of_ingests=NUMBER_OF_INGESTS,
            timeout=INGESTS_CONNECT_TIMEOUT,
        )
        self.moblin.go_live()
        self.moblin.wait_for_bitrate(*self._stream_bitrate_range, None, 3_000_000)
        mediamtx.wait_for_srt_stream(STREAM_PATH, 3_000_000)

    def _create_monitor(self, mediamtx: MediaMtx, sources: list[Source]) -> Monitor:
        return Monitor(
            moblin=self.moblin,
            mediamtx=mediamtx,
            stream_path=STREAM_PATH,
            source_names=[source.name for source in sources],
            number_of_ingests=NUMBER_OF_INGESTS,
            stream_bitrate_range=self._stream_bitrate_range,
            ingests_bitrate_range=self._ingests_bitrate_range,
            poll_interval=POLL_INTERVAL,
            stream_content=self._create_stream_content_expectation(),
            deviation_timeout=self._deviation_timeout,
            shaping="" if self._shaper is None else self._shaper.description(),
        )

    def _create_stream_content_expectation(self) -> StreamContentExpectation:
        expectation = StreamContentExpectation(
            url=srt_reader_url(STREAM_PATH),
            path=STREAM_CONTENT_FILE,
            width=STREAM_WIDTH,
            height=STREAM_HEIGHT,
            fps=STREAM_FPS,
        )
        if self._stream_profile is None:
            return expectation
        return replace(
            expectation,
            minimum_fps_ratio=SHAPED_STREAM_CONTENT_MINIMUM_FPS_RATIO,
            minimum_unique_video_frames_ratio=(
                SHAPED_STREAM_CONTENT_MINIMUM_UNIQUE_VIDEO_FRAMES_RATIO
            ),
        )

    def _monitor_until_done(self, monitor: Monitor, sources: list[Source]):
        end_time = time.monotonic() + self._duration
        next_poll_time = time.monotonic()
        next_log_time = time.monotonic()
        while time.monotonic() < end_time:
            next_poll_time += POLL_INTERVAL
            time.sleep(max(0, next_poll_time - time.monotonic()))
            if self._shaper is not None:
                self._shaper.poll()
            restart_dead_sources(monitor, sources)
            monitor.poll()
            if time.monotonic() >= next_log_time:
                monitor.log_status()
                next_log_time += LOG_INTERVAL


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


def name_scene_widget_settings(widget_id: str, x: float, y: float, alignment: str):
    return scene_widget_settings(widget_id, x=x, y=y, size=100, alignment=alignment)


def restart_dead_sources(monitor: Monitor, sources: list[Source]):
    for source in sources:
        if not source.command.is_running():
            monitor.source_restarted(source.name)
            source.command.restart()


def shaped_bitrate_range(
    nominal_bitrate: float,
    profile: Profile | None,
    default_range: tuple[float, float],
) -> tuple[float, float]:
    if profile is None:
        return default_range
    minimum_rate = profile.minimum_rate()
    maximum_rate = profile.maximum_rate()
    if minimum_rate is None or maximum_rate is None:
        return default_range
    return (
        SHAPED_BITRATE_MINIMUM_FACTOR * min(nominal_bitrate, minimum_rate),
        SHAPED_BITRATE_MAXIMUM_FACTOR * min(nominal_bitrate, maximum_rate),
    )


def create_traffic_shaper(
    config: Config,
    stream_traffic_shaping_profile: str | None,
    stream_traffic_shaping_parameters: str | None,
    ingests_traffic_shaping_profile: str | None,
    ingests_traffic_shaping_parameters: str | None,
) -> TrafficShaper | None:
    profiles = {}
    if stream_traffic_shaping_profile is not None:
        profiles[STREAM_GROUP] = parse_profile(
            stream_traffic_shaping_profile, stream_traffic_shaping_parameters
        )
    if ingests_traffic_shaping_profile is not None:
        profiles[INGESTS_GROUP] = parse_profile(
            ingests_traffic_shaping_profile, ingests_traffic_shaping_parameters
        )
    if len(profiles) == 0:
        return None
    return TrafficShaper(config, RELAYS, profiles)


def tests(
    moblin: Moblin,
    duration: float,
    shaper: TrafficShaper | None,
):
    return [
        StabilityFourIngestsOneStream(moblin, duration, shaper),
    ]


@dataclass
class Source:
    name: str
    command: FfmpegCommand
