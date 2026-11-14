import logging
import time
from concurrent.futures import ThreadPoolExecutor
from contextlib import ExitStack
from dataclasses import dataclass
from datetime import UTC
from datetime import datetime
from enum import StrEnum
from pathlib import Path

from humanfriendly import format_size
from systest import wait_until
from systest_moblin.ffmpeg import FfmpegCommand
from systest_moblin.ffmpeg import FfmpegRtspTestStream
from systest_moblin.ffmpeg import FfmpegTestStream
from systest_moblin.ffmpeg import StreamRecorder
from systest_moblin.ffmpeg import TransportFormat
from systest_moblin.ffmpeg import ffprobe_audio

from ..utils.audio_video_sync import AlertSyncReport
from ..utils.audio_video_sync import alert_chat_message
from ..utils.audio_video_sync import alert_media_files
from ..utils.audio_video_sync import alerts_media_gallery_settings
from ..utils.audio_video_sync import alerts_widget_settings
from ..utils.audio_video_sync import measure_alert_synchronization
from ..utils.config import RIST_SERVER_PORT
from ..utils.config import RTMP_CLIENT_STABILITY_SERVER_PORT
from ..utils.config import RTMP_SERVER_PORT
from ..utils.config import SRT_CLIENT_STABILITY_RELAYED_SERVER_PORT
from ..utils.config import SRT_CLIENT_STABILITY_SERVER_PORT
from ..utils.config import SRT_HIGH_LATENCY
from ..utils.config import SRT_SERVER_PORT
from ..utils.config import TESTER_RIST_PORT
from ..utils.config import TESTER_RIST_RELAYED_PORT
from ..utils.config import TESTER_WEBRTC_PORT
from ..utils.config import TESTER_WEBRTC_UDP_PORT
from ..utils.config import rist_listener_url
from ..utils.config import rtmp_listener_url
from ..utils.config import rtsp_reader_url
from ..utils.config import srt_listener_url
from ..utils.generate_device_settings import Alignment
from ..utils.generate_device_settings import BitrateRateControl
from ..utils.generate_device_settings import CameraPosition
from ..utils.generate_device_settings import Resolution
from ..utils.generate_device_settings import SceneName
from ..utils.generate_device_settings import scene_widget_settings
from ..utils.generate_device_settings import text_widget_settings
from ..utils.generate_device_settings import uuid
from ..utils.generate_device_settings import video_source_widget_settings
from ..utils.lossy_udp_relay import LossyUdpRelay
from ..utils.mediamtx import MediaMtx
from ..utils.moblin import Moblin
from ..utils.monitor import Monitor
from ..utils.network_capture import CaptureStream
from ..utils.network_capture import NetworkCapture
from ..utils.network_capture import Protocol
from ..utils.test_case import TestCase
from ..utils.timecodes import TimecodeReport
from ..utils.timecodes import measure_timecodes
from ..utils.timecodes import write_timecodes_html
from ..utils.utils import FILES_DIR
from ..utils.utils import Range
from ..utils.utils import manual_requirement
from ..utils.utils import manual_volume_requirement
from ..utils.utils import sleep_unless_quit

LOGGER = logging.getLogger(__name__)


class Ingest(StrEnum):
    RTMP = "rtmp"
    SRT = "srt"
    RIST = "rist"
    WHEP = "whep"

    def label(self) -> str:
        return self.name


class StreamProtocol(StrEnum):
    SRT = "srt"
    RTMP = "rtmp"
    RIST = "rist"


WHEP_PATH = "stabilitywhep"
STREAM_PATH = "stability"
INGEST_BITRATE = 5_000_000
STREAM_BITRATE = 5_000_000
STREAM_BITRATE_RANGE = Range(4_000_000, 6_500_000)
RELAYED_STREAM_BITRATE_RANGE = Range(1_000_000, 6_500_000)
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
INGEST_CAPTURE_STREAMS = [
    CaptureStream("RTMP", Protocol.TCP, RTMP_SERVER_PORT),
    CaptureStream("SRT", Protocol.UDP, SRT_SERVER_PORT),
    CaptureStream("RIST", Protocol.UDP, RIST_SERVER_PORT),
    CaptureStream("WHEP", Protocol.TCP, TESTER_WEBRTC_PORT),
    CaptureStream("WHEP", Protocol.UDP, TESTER_WEBRTC_UDP_PORT),
]
RTMP_STREAM_ID = uuid()
SRT_STREAM_ID = uuid()
RIST_STREAM_ID = uuid()
WHEP_STREAM_ID = uuid()
RTMP_WIDGET_ID = uuid()
SRT_WIDGET_ID = uuid()
RIST_WIDGET_ID = uuid()
WHEP_WIDGET_ID = uuid()
ALERT_WIDGET_ID = uuid()
ALERT_WIDGET_X = 40.0
ALERT_WIDGET_Y = 40.0
ALERT_INTERVAL = 15 * 60
FIRST_ALERT_DELAY = 60
MAXIMUM_ALERT_OFFSET_SPREAD = 0.25
MAXIMUM_ALERT_OFFSET_DRIFT = 0.1
TIMECODE_STREAM_PROTOCOLS = [StreamProtocol.SRT, StreamProtocol.RIST]
RELAYED_STREAM_PROTOCOLS = [StreamProtocol.SRT, StreamProtocol.RIST]
PACKET_LOSS_PERCENT = 1
TIMECODE_WINDOWS = 12
MAXIMUM_TIMECODE_SPREAD = 0.25
MAXIMUM_TIMECODE_DRIFT = 0.5
MINIMUM_TIMECODE_DRIFT_SPAN = 1800
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
        stream_protocol: StreamProtocol,
        duration: float,
        video_bitrate_control: BitrateRateControl,
        network_capture: bool,
    ):
        super().__init__(moblin)
        self._ingests = ingests
        self._stream_protocol = stream_protocol
        self._duration = duration
        self._video_bitrate_control = video_bitrate_control
        self._network_capture = network_capture
        self._capture: NetworkCapture | None = None
        self._monitor: Monitor | None = None
        self._relays: dict[str, LossyUdpRelay] = {}
        self._stream_relayed = stream_protocol in RELAYED_STREAM_PROTOCOLS
        self._stream_bitrate_range = (
            RELAYED_STREAM_BITRATE_RANGE if self._stream_relayed else STREAM_BITRATE_RANGE
        )
        self._ingests_bitrate_range = ingests_bitrate_range(len(ingests))
        self._alert_times: list[float] = []
        self._stream_started: datetime | None = None

    def setup(self):
        self.moblin.import_settings(
            overrides={
                "streams": [
                    {
                        "name": "Stability",
                        "enabled": True,
                        **self._stream_protocol_settings(),
                        "bitrateRateControl": self._video_bitrate_control,
                        "bitrate": STREAM_BITRATE,
                        "fps": STREAM_FPS,
                        "resolution": STREAM_RESOLUTION,
                        "timecodesEnabled": True,
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
                    alerts_widget_settings("Alert", ALERT_WIDGET_ID),
                ],
                "alertsMediaGallery": alerts_media_gallery_settings(),
                "chat": {
                    "botEnabled": True,
                    "botCommandPermissions": {"alert": {"moderatorsEnabled": True}, "migrated": True},
                },
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
                    "streams": [{"id": RIST_STREAM_ID, "name": "1", "virtualDestinationPort": 2}],
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
            },
            files=alert_media_files(),
        )
        time.sleep(2)

    def run(self):
        manual_requirement(
            LOGGER,
            "Keep the device connected to power with the app in the foreground",
        )
        manual_volume_requirement(LOGGER)
        with ExitStack() as stack:
            capture = self._enter_network_capture(stack)
            self._enter_relays(stack)
            mediamtx = stack.enter_context(MediaMtx(log_level="warn"))
            stream_recorder = stack.enter_context(
                StreamRecorder(
                    stream_recorder_url(self._stream_protocol),
                    STREAM_FILE,
                )
            )
            sources = self._create_sources()
            for source in sources:
                stack.enter_context(source.command)
            if Ingest.WHEP in self._ingests:
                mediamtx.wait_for_rtsp_publisher(WHEP_PATH, 1_000_000)
            self._wait_for_ingests()
            self._go_live(stream_recorder)
            self.moblin.start_recording()
            self._monitor = self._create_monitor(stream_recorder, sources)
            self._monitor_until_done(self._monitor, stream_recorder, sources, capture)
            self.moblin.end()
            self.moblin.stop_recording()
            recording = self._download_recording()
        self._validate(stream_recorder, recording)

    def teardown(self):
        if self._monitor is not None:
            self._monitor.report()
        self._report_network_capture()
        try:
            super().teardown()
        except Exception as error:
            LOGGER.warning("Failed to stop the app. Did it crash? %s", error)

    def _stream_protocol_settings(self) -> dict:
        adaptive_bitrate = {"adaptiveBitrateEnabled": self._stream_relayed}
        match self._stream_protocol:
            case StreamProtocol.SRT:
                return {
                    "url": self.moblin.tester_srt_url(SRT_CLIENT_STABILITY_SERVER_PORT),
                    "srt": adaptive_bitrate,
                }
            case StreamProtocol.RTMP:
                return {
                    "url": self.moblin.tester_rtmp_url(STREAM_PATH, RTMP_CLIENT_STABILITY_SERVER_PORT),
                    "rtmp": adaptive_bitrate,
                }
            case StreamProtocol.RIST:
                return {
                    "url": self.moblin.tester_rist_url(),
                    "rist": {**adaptive_bitrate, "bonding": False},
                }

    def _download_recording(self) -> Path | None:
        LOGGER.debug("Downloading the recording...")
        try:
            recording = self.moblin.download_and_delete_latest_recording(RECORDING_FILE_NAME)
        except Exception as error:
            LOGGER.warning("Failed to download the recording. %s", error)
            return None
        LOGGER.info(
            "Downloaded the recording to %s (%s).",
            recording,
            format_size(recording.stat().st_size),
        )
        return recording

    def _validate(self, recorder: StreamRecorder, recording: Path | None):
        files = [recorder.file]
        if recording is not None:
            files.insert(0, recording)
        reports = []
        with ThreadPoolExecutor() as executor:
            audio_futures = [executor.submit(ffprobe_audio, file) for file in files]
            report_futures = [executor.submit(self._measure_alert_synchronization, file) for file in files]
            timecode_future = executor.submit(self._measure_timecodes, recorder)
            for future in report_futures:
                report = future.result()
                if report is None:
                    continue
                report.log()
                reports.append(report)
            audios = [future.result() for future in audio_futures]
            timecode_report = timecode_future.result()
        for file, audio in zip(files, audios):
            self._assert_audio_presentation_time_stamps(file, audio)
        self._assert_alerts_synchronized(reports, recording)
        self._assert_timecodes(timecode_report)

    def _measure_alert_synchronization(self, file: Path) -> AlertSyncReport | None:
        if len(self._alert_times) < 2:
            return None
        try:
            return measure_alert_synchronization(file, self._alert_times, ALERT_WIDGET_X, ALERT_WIDGET_Y)
        except Exception as error:
            LOGGER.warning("Failed to measure alert synchronization in %s. %s", file, error)
            return None

    def _assert_alerts_synchronized(self, reports: list[AlertSyncReport], recording: Path | None):
        for report in reports:
            if report.path == recording:
                self.assert_equal(len(report.missing), 0)
            if len(report.alerts) < 2:
                continue
            self.assert_less(report.spread(), MAXIMUM_ALERT_OFFSET_SPREAD)
            self.assert_less(abs(report.drift()), MAXIMUM_ALERT_OFFSET_DRIFT)

    def _assert_timecodes(self, report: TimecodeReport | None):
        if report is None:
            return
        report.log()
        self._write_timecodes_html(report)
        self.assert_greater(report.frames, 0)
        self.assert_equal(report.missing, 0)
        self.assert_equal(report.outside, 0)
        self.assert_less(report.spread(), MAXIMUM_TIMECODE_SPREAD)
        if report.span() > MINIMUM_TIMECODE_DRIFT_SPAN:
            self.assert_less(abs(report.drift()), MAXIMUM_TIMECODE_DRIFT)

    def _measure_timecodes(self, recorder: StreamRecorder) -> TimecodeReport | None:
        if self._stream_started is None:
            return None
        if self._stream_protocol not in TIMECODE_STREAM_PROTOCOLS:
            return None
        try:
            return measure_timecodes(recorder.file, self._stream_started, TIMECODE_WINDOWS)
        except Exception as error:
            LOGGER.warning("Failed to measure SEI timecodes in %s. %s", recorder.file, error)
            return None

    def _write_timecodes_html(self, report: TimecodeReport):
        file = FILES_DIR / f"{STREAM_PATH}-timecodes.html"
        try:
            write_timecodes_html(file, report, self._settings())
        except Exception as error:
            LOGGER.warning("Failed to write the SEI timecode graphs. %s", error)
            return
        LOGGER.info("Open the timecode graphs with 'open %s'.", file)

    def _trigger_alert(self):
        self.moblin.set_scene(SceneName.FRONT)
        time.sleep(3)
        self.moblin.send_chat_message(alert_chat_message())
        self._alert_times.append(time.monotonic())
        LOGGER.info("Triggered alert %s.", len(self._alert_times) - 1)
        time.sleep(7)

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
                    files_dir=FILES_DIR,
                    video_bitrate=INGEST_BITRATE,
                    loop_audio=True,
                    quiet=True,
                )
            case Ingest.SRT:
                return FfmpegTestStream(
                    url=self._ingest_url(ingest, self.moblin.ingest_srt_url(latency=SRT_HIGH_LATENCY)),
                    files_dir=FILES_DIR,
                    video_bitrate=INGEST_BITRATE,
                    loop_audio=True,
                    quiet=True,
                    transport_format=TransportFormat.MPEGTS,
                )
            case Ingest.RIST:
                return FfmpegTestStream(
                    url=self._ingest_url(ingest, self.moblin.ingest_rist_url()),
                    files_dir=FILES_DIR,
                    video_bitrate=INGEST_BITRATE,
                    loop_audio=True,
                    quiet=True,
                    transport_format=TransportFormat.MPEGTS,
                )
            case Ingest.WHEP:
                return FfmpegRtspTestStream(
                    url=rtsp_reader_url(WHEP_PATH),
                    files_dir=FILES_DIR,
                    video_bitrate=INGEST_BITRATE,
                    loop_audio=True,
                    quiet=True,
                )

    def _enter_relays(self, stack: ExitStack):
        if self._stream_relayed:
            self._relays["Stream"] = stack.enter_context(stream_relay(self._stream_protocol))
        for ingest, url in [
            (Ingest.SRT, self.moblin.ingest_srt_url()),
            (Ingest.RIST, self.moblin.ingest_rist_url()),
        ]:
            if ingest in self._ingests:
                self._relays[ingest.label()] = stack.enter_context(
                    LossyUdpRelay.from_url(url, PACKET_LOSS_PERCENT)
                )

    def _ingest_url(self, ingest: Ingest, url: str) -> str:
        relay = self._relays.get(ingest.label())
        if relay is None:
            return url
        return relay.relayed_url(url)

    def _wait_for_ingests(self):
        if len(self._ingests) == 0:
            return
        self.moblin.wait_for_ingests(
            self._ingests_bitrate_range,
            total_bytes=0,
            number_of_ingests=len(self._ingests),
        )

    def _go_live(self, stream_recorder: StreamRecorder):
        self._stream_started = datetime.now(UTC)
        self.moblin.go_live()
        self.moblin.wait_for_bitrate(
            self._stream_bitrate_range.minimum,
            self._stream_bitrate_range.maximum,
            None,
            3_000_000,
        )
        wait_until(lambda: stream_recorder.total_bytes() > 3_000_000, "the stream to be recorded to disk")

    def _create_monitor(self, stream_recorder: StreamRecorder, sources: list[Source]) -> Monitor:
        return Monitor(
            moblin=self.moblin,
            stream_recorder=stream_recorder,
            source_names=[source.name for source in sources],
            number_of_ingests=len(self._ingests),
            stream_bitrate_range=self._stream_bitrate_range,
            ingests_bitrate_range=self._ingests_bitrate_range,
            duration=self._duration,
            relays=self._relays,
        )

    def _enter_network_capture(self, stack: ExitStack) -> NetworkCapture | None:
        if not self._network_capture:
            return None
        streams = [stream_capture_stream(self._stream_protocol)] + INGEST_CAPTURE_STREAMS
        self._capture = stack.enter_context(
            NetworkCapture([self.moblin.ip_address], FILES_DIR, STREAM_PATH, streams, self._settings())
        )
        return self._capture

    def _settings(self) -> dict[str, str]:
        return {
            "Device": self.moblin.device_name,
            "Stream protocol": self._stream_protocol.name,
            "Video bitrate control": str(self._video_bitrate_control),
            "Video bitrate": f"{STREAM_BITRATE / 1e6:.1f} Mbps",
            "Adaptive bitrate": "enabled" if self._stream_relayed else "disabled",
            "Packet loss": f"{PACKET_LOSS_PERCENT} % on SRT and RIST",
        }

    def _report_network_capture(self):
        if self._capture is None:
            return
        try:
            self._capture.report()
        except Exception as error:
            LOGGER.warning("Failed to analyze the network capture. %s", error)

    def _monitor_until_done(
        self,
        monitor: Monitor,
        recorder: StreamRecorder,
        sources: list[Source],
        capture: NetworkCapture | None,
    ):
        end_time = time.monotonic() + self._duration
        alert_time = time.monotonic() + FIRST_ALERT_DELAY
        LOGGER.info("Type q and press ENTER to end the test early.")
        while time.monotonic() < end_time:
            if sleep_unless_quit(LOGGER, 5):
                break
            self.moblin.set_scene(SceneName.BACK)
            if sleep_unless_quit(LOGGER, 5):
                break
            self.moblin.set_scene(SceneName.FRONT)
            if time.monotonic() >= alert_time:
                self._trigger_alert()
                alert_time += ALERT_INTERVAL
            monitor.poll()
            restart_dead_sources(monitor, sources)
            recorder.poll()
            if capture is not None:
                capture.poll()


def stream_capture_stream(stream_protocol: StreamProtocol) -> CaptureStream:
    match stream_protocol:
        case StreamProtocol.SRT:
            return CaptureStream("Stream", Protocol.UDP, SRT_CLIENT_STABILITY_SERVER_PORT)
        case StreamProtocol.RTMP:
            return CaptureStream("Stream", Protocol.TCP, RTMP_CLIENT_STABILITY_SERVER_PORT)
        case StreamProtocol.RIST:
            return CaptureStream("Stream", Protocol.UDP, TESTER_RIST_PORT)


def stream_relay(stream_protocol: StreamProtocol) -> LossyUdpRelay:
    match stream_protocol:
        case StreamProtocol.SRT:
            port, relayed_port = SRT_CLIENT_STABILITY_SERVER_PORT, SRT_CLIENT_STABILITY_RELAYED_SERVER_PORT
        case StreamProtocol.RIST:
            port, relayed_port = TESTER_RIST_PORT, TESTER_RIST_RELAYED_PORT
        case StreamProtocol.RTMP:
            raise Exception("RTMP streams cannot be relayed.")
    return LossyUdpRelay(("127.0.0.1", relayed_port), ("0.0.0.0", port), PACKET_LOSS_PERCENT)


def stream_recorder_url(stream_protocol: StreamProtocol) -> str:
    match stream_protocol:
        case StreamProtocol.SRT:
            return srt_listener_url(SRT_CLIENT_STABILITY_RELAYED_SERVER_PORT)
        case StreamProtocol.RTMP:
            return rtmp_listener_url(STREAM_PATH, RTMP_CLIENT_STABILITY_SERVER_PORT)
        case StreamProtocol.RIST:
            return rist_listener_url(TESTER_RIST_RELAYED_PORT)


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
            scene_widget_settings(ALERT_WIDGET_ID, x=ALERT_WIDGET_X, y=ALERT_WIDGET_Y, size=100),
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


def tests(
    moblin: Moblin,
    ingests: list[Ingest],
    stream_protocol: StreamProtocol,
    duration: float,
    video_bitrate_control: BitrateRateControl,
    network_capture: bool,
):
    return [
        StabilityIngestsOneStream(
            moblin,
            ingests,
            stream_protocol,
            duration,
            video_bitrate_control,
            network_capture,
        ),
    ]
