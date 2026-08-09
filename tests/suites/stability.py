import logging
import time
from contextlib import ExitStack
from dataclasses import dataclass

from utils.config import RIST_SERVER_PORT
from utils.config import RTMP_SERVER_PORT
from utils.config import SRT_SERVER_PORT
from utils.config import TESTER_RTSP_PORT
from utils.ffmpeg import FfmpegCommand
from utils.ffmpeg import FfmpegRtspTestStream
from utils.ffmpeg import FfmpegTestStream
from utils.generate_device_settings import scene_widget_settings
from utils.generate_device_settings import uuid
from utils.generate_device_settings import video_source_widget_settings
from utils.mediamtx import MediaMtx
from utils.moblin import Moblin
from utils.monitor import Monitor
from utils.monitor import format_duration
from utils.test_case import TestCase
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
RTMP_STREAM_ID = uuid()
SRT_STREAM_ID = uuid()
RIST_STREAM_ID = uuid()
WHEP_STREAM_ID = uuid()
SRT_WIDGET_ID = uuid()
RIST_WIDGET_ID = uuid()
WHEP_WIDGET_ID = uuid()


class StabilityFourIngestsOneStream(TestCase):
    """Four ingests (RTMP, SRT, RIST and WHEP) and one outgoing SRT stream, all roughly
    5 Mbps, active at the same time for 12 hours, or until the app crashes.

    All four ingests are shown in the scene, so all of them are decoded and composited.
    Bitrates, reconnections, ingests, CPU load, memory usage, thermal state and battery
    level are monitored continuously. The test fails if the app crashes, becomes
    unresponsive, or if anything is outside its accepted range for too long.

    """

    def __init__(self, moblin: Moblin, duration: float = DEFAULT_DURATION):
        super().__init__(moblin)
        self._duration = duration
        self._monitor: Monitor | None = None

    def setup(self):
        self.moblin.import_settings(
            overrides={
                "streams": [
                    {
                        "name": "Stability",
                        "enabled": True,
                        "url": self.moblin.tester_srt_publish_url(STREAM_PATH),
                        "srt": {"adaptiveBitrateEnabled": False},
                        "bitrateRateControl": "CBR",
                        "bitrate": STREAM_BITRATE,
                        "fps": 30,
                        "resolution": "1920x1080",
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
                                SRT_WIDGET_ID, x=0, y=0, size=33, alignment="TopRight"
                            ),
                            scene_widget_settings(
                                RIST_WIDGET_ID,
                                x=0,
                                y=0,
                                size=33,
                                alignment="BottomLeft",
                            ),
                            scene_widget_settings(
                                WHEP_WIDGET_ID,
                                x=0,
                                y=0,
                                size=33,
                                alignment="BottomRight",
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
        with MediaMtx(log_level="warn") as mediamtx:
            with ExitStack() as stack:
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

    def _go_live(self, mediamtx: MediaMtx):
        self.moblin.wait_for_ingests(
            *INGESTS_BITRATE_RANGE,
            total_bytes=0,
            number_of_ingests=NUMBER_OF_INGESTS,
            timeout=INGESTS_CONNECT_TIMEOUT,
        )
        self.moblin.go_live()
        self.moblin.wait_for_bitrate(*STREAM_BITRATE_RANGE, None, 3_000_000)
        mediamtx.wait_for_srt_stream(STREAM_PATH, 3_000_000)

    def _create_monitor(self, mediamtx: MediaMtx, sources: list[Source]) -> Monitor:
        return Monitor(
            moblin=self.moblin,
            mediamtx=mediamtx,
            stream_path=STREAM_PATH,
            source_names=[source.name for source in sources],
            number_of_ingests=NUMBER_OF_INGESTS,
            stream_bitrate_range=STREAM_BITRATE_RANGE,
            ingests_bitrate_range=INGESTS_BITRATE_RANGE,
            poll_interval=POLL_INTERVAL,
        )

    def _monitor_until_done(self, monitor: Monitor, sources: list[Source]):
        LOGGER.info(
            "Streaming %d ingests and one stream. Monitoring the app for %s.",
            NUMBER_OF_INGESTS,
            format_duration(self._duration),
        )
        end_time = time.monotonic() + self._duration
        next_poll_time = time.monotonic()
        next_log_time = time.monotonic()
        while time.monotonic() < end_time:
            next_poll_time += POLL_INTERVAL
            time.sleep(max(0, next_poll_time - time.monotonic()))
            restart_dead_sources(monitor, sources)
            monitor.poll()
            if time.monotonic() >= next_log_time:
                monitor.log_status()
                next_log_time += LOG_INTERVAL


def restart_dead_sources(monitor: Monitor, sources: list[Source]):
    for source in sources:
        if not source.command.is_running():
            monitor.source_restarted(source.name)
            source.command.restart()


def tests(moblin: Moblin, duration: float = DEFAULT_DURATION):
    return [
        StabilityFourIngestsOneStream(moblin, duration),
    ]


@dataclass
class Source:
    name: str
    command: FfmpegCommand
