import logging
import time
from contextlib import contextmanager
from dataclasses import dataclass
from datetime import UTC
from datetime import datetime
from pathlib import Path

from systest_moblin.ffmpeg import FfmpegServer

from ..utils.audio_video_sync import alert_chat_message
from ..utils.audio_video_sync import alert_media_files
from ..utils.audio_video_sync import alerts_media_gallery_settings
from ..utils.audio_video_sync import alerts_widget_settings
from ..utils.audio_video_sync import measure_alert_synchronization
from ..utils.config import SRT_SERVER_PORT
from ..utils.config import SRTLA_SERVER_PORT
from ..utils.config import TESTER_SRTLA_PORT
from ..utils.config import TESTER_SRTLA_SRT_PORT
from ..utils.config import WEB_REMOTE_CONTROL_PORT
from ..utils.config import Capability
from ..utils.config import rist_listener_url
from ..utils.config import srt_listener_url
from ..utils.generate_device_settings import BACK_SCENE_SETTINGS
from ..utils.generate_device_settings import RECORD_STREAM_SETTINGS
from ..utils.generate_device_settings import AudioCodec
from ..utils.generate_device_settings import BitrateRateControl
from ..utils.generate_device_settings import CameraPosition
from ..utils.generate_device_settings import Resolution
from ..utils.generate_device_settings import SceneName
from ..utils.generate_device_settings import VideoCodec
from ..utils.generate_device_settings import VideoStabilizationMode
from ..utils.generate_device_settings import mic_id
from ..utils.generate_device_settings import scene_widget_settings
from ..utils.generate_device_settings import uuid
from ..utils.mediamtx import MediaMtx
from ..utils.moblin import Moblin
from ..utils.moblin import Recorder
from ..utils.moblin import create_receiver
from ..utils.test_case import TestCase
from ..utils.utils import FILES_DIR
from ..utils.utils import Range
from ..utils.utils import format_generic_stream_url_stream_name
from ..utils.utils import manual_volume_requirement

LOGGER = logging.getLogger(__name__)
SRTLA_INGEST_ID = uuid()
SRTLA_STREAM_ID = "1"
ALERT_WIDGET_ID = uuid()
ALERT_WIDGET_X = 40.0
ALERT_WIDGET_Y = 40.0
ALERT_DELAY = 5
ALERT_INTERVAL = 7
NUMBER_OF_ALERTS = 3
MAXIMUM_OFFSET_SPREAD = 0.15
MAXIMUM_OFFSET_ERROR = 0.15
VIDEO_STABILIZATION_OFFSETS = {
    VideoStabilizationMode.OFF: 0.0,
    VideoStabilizationMode.STANDARD: 0.1,
    VideoStabilizationMode.CINEMATIC: 0.5,
}


class StreamTestCase(TestCase):
    def import_stream_settings(self, **stream):
        self.moblin.import_settings(
            overrides={
                "streams": [
                    {
                        "enabled": True,
                        "bitrateRateControl": BitrateRateControl.CBR,
                        **stream,
                    }
                ],
            }
        )

    def stream_to_ffmpeg(
        self,
        url: str,
        minimum_bitrate: int,
        maximum_bitrate: int,
        total_bytes: int,
    ) -> Path:
        filename = FILES_DIR / f"{self.name}.ts"
        self.moblin.set_scene(SceneName.FRONT)
        with FfmpegServer(url=url, filename=filename):
            self.moblin.go_live()
            self.moblin.wait_for_bitrate(minimum_bitrate, maximum_bitrate, None, total_bytes)
            self.moblin.end()
        return filename

    @contextmanager
    def stream_to_mediamtx(
        self,
        minimum_bitrate: int,
        maximum_bitrate: int,
        total_bytes: int,
        multi_streaming: str | None = None,
    ):
        self.moblin.set_scene(SceneName.FRONT)
        with MediaMtx() as mediamtx:
            self.moblin.go_live()
            self.moblin.wait_for_bitrate(minimum_bitrate, maximum_bitrate, multi_streaming, total_bytes)
            yield mediamtx
            self.moblin.end()


class StreamRtmpToMediaMtx(StreamTestCase):
    """RTMP stream from Moblin to MediaMTX for a few seconds."""

    def setup(self):
        self.import_stream_settings(
            url=self.moblin.tester_rtmp_url("test"),
            rtmp={"adaptiveBitrateEnabled": False},
        )

    def run(self):
        with self.stream_to_mediamtx(4_500_000, 5_500_000, 10_000_000) as mediamtx:
            mediamtx.wait_for_rtmp_stream("test", 10_000_000)


class StreamSrtToMediaMtx(StreamTestCase):
    """SRT stream from Moblin to MediaMTX for a few seconds."""

    def setup(self):
        self.import_stream_settings(
            url=self.moblin.tester_srt_publish_url("test"),
            srt={"adaptiveBitrateEnabled": False},
            bitrate=50_000_000,
        )

    def run(self):
        with self.stream_to_mediamtx(49_000_000, 51_000_000, 100_000_000) as mediamtx:
            mediamtx.wait_for_srt_stream("test", 100_000_000)


class StreamSrtToFfmpeg(StreamTestCase):
    """SRT stream from Moblin to ffmpeg for a few seconds."""

    def __init__(self, moblin: Moblin, resolution: Resolution, fps: int):
        super().__init__(moblin, f"StreamSrtToFfmpeg-{resolution}@{fps}")
        self._resolution = resolution
        self._fps = fps

    def setup(self):
        if self._fps == 60:
            self.skip_if_missing_capability(Capability.PIP)
        self.import_stream_settings(
            url=self.moblin.tester_srt_publish_url("test"),
            srt={"adaptiveBitrateEnabled": False},
            bitrate=5_000_000,
            resolution=self._resolution,
            fps=self._fps,
        )

    def run(self):
        filename = self.stream_to_ffmpeg(srt_listener_url(), 4_000_000, 6_000_000, 10_000_000)
        width, height = self._resolution.size()
        self.assert_live_stream(filename, width=width, height=height, fps=self._fps)


class StreamSrtToFfmpegHighBitrate(StreamTestCase):
    """SRT stream from Moblin to ffmpeg at 50 Mbps for a few seconds."""

    def setup(self):
        self.import_stream_settings(
            url=self.moblin.tester_srt_publish_url("test"),
            srt={"adaptiveBitrateEnabled": False},
            bitrate=50_000_000,
        )

    def run(self):
        filename = self.stream_to_ffmpeg(srt_listener_url(), 49_000_000, 51_000_000, 50_000_000)
        self.assert_live_stream(filename, minimum_length=1, maximum_length=10)


class StreamSrtToFfmpegEncrypted(StreamTestCase):
    """Encrypted SRT stream from Moblin to ffmpeg for a few seconds."""

    PASSPHRASE = "1234567890"

    def setup(self):
        self.import_stream_settings(
            url=self.moblin.tester_srt_publish_url("test", self.PASSPHRASE),
            srt={"adaptiveBitrateEnabled": False, "implementation": "Official"},
            bitrate=5_000_000,
        )

    def run(self):
        filename = self.stream_to_ffmpeg(
            srt_listener_url(passphrase=self.PASSPHRASE),
            4_000_000,
            6_000_000,
            10_000_000,
        )
        self.assert_live_stream(filename)


class StreamSrtToFfmpegTimecodes(StreamTestCase):
    """SRT stream with SEI timecodes from Moblin to ffmpeg for a few seconds."""

    def setup(self):
        self.import_stream_settings(
            url=self.moblin.tester_srt_publish_url("test"),
            srt={"adaptiveBitrateEnabled": False},
            codec=VideoCodec.H265,
            bitrate=5_000_000,
            timecodesEnabled=True,
            ntpPoolAddress="time.apple.com",
        )

    def run(self):
        started = datetime.now(UTC)
        filename = self.stream_to_ffmpeg(srt_listener_url(), 4_000_000, 6_000_000, 10_000_000)
        self.assert_live_stream(filename)
        self.assert_timecodes(filename, started, datetime.now(UTC))


class StreamSrtToFfmpegVideoRateControl(StreamTestCase):
    """SRT stream from Moblin to ffmpeg for a few seconds using given video rate control."""

    def __init__(self, moblin: Moblin, rate_control: BitrateRateControl):
        super().__init__(moblin, f"StreamSrtToFfmpegVideoRateControl{rate_control.title()}")
        self._rate_control = rate_control

    def setup(self):
        if self._rate_control != BitrateRateControl.CBR:
            self.skip_if_no_moving_picture()
            self.moving_picture_on()
        self.import_stream_settings(
            bitrateRateControl=self._rate_control,
            url=self.moblin.tester_srt_publish_url("test"),
            bitrate=5_000_000,
        )

    def run(self):
        filename = self.stream_to_ffmpeg(srt_listener_url(), 4_000_000, 6_000_000, 5_000_000)
        self.assert_live_stream(filename)


class StreamRistToFfmpeg(StreamTestCase):
    """RIST stream from Moblin to ffmpeg for a few seconds."""

    def setup(self):
        self.import_stream_settings(
            url=self.moblin.tester_rist_url(),
            rist={"adaptiveBitrateEnabled": False, "bonding": False},
            bitrate=5_000_000,
        )

    def run(self):
        filename = self.stream_to_ffmpeg(rist_listener_url(), 4_000_000, 6_000_000, 10_000_000)
        self.assert_live_stream(filename)


class StreamRistBondingToFfmpeg(StreamTestCase):
    """RIST stream with bonding from Moblin to ffmpeg, checking the bonding bytes per second."""

    def setup(self):
        self.import_stream_settings(
            url=self.moblin.tester_rist_url(),
            rist={"adaptiveBitrateEnabled": False, "bonding": True},
            bitrate=5_000_000,
        )

    def run(self):
        filename = FILES_DIR / f"{self.name}.ts"
        self.moblin.set_scene(SceneName.FRONT)
        with FfmpegServer(url=rist_listener_url(), filename=filename):
            self.moblin.go_live()
            self.moblin.wait_for_bitrate(4_000_000, 6_000_000, None, 10_000_000)
            self.moblin.wait_for_bitrate_info(Range(4_000_000, 6_000_000), 10_000_000)
            self.moblin.wait_for_bonding_bytes_per_second(Range(500_000, 750_000))
            self.moblin.end()
        self.assert_live_stream(filename)


class StreamSrtlaToSelf(StreamTestCase):
    """SRTLA stream from Moblin to its own SRTLA server ingest, checking the bitrate and bonding info."""

    def setup(self):
        self.moblin.import_settings(
            overrides={
                "streams": [
                    {
                        "enabled": True,
                        "bitrateRateControl": BitrateRateControl.CBR,
                        "url": self.moblin.ingest_srtla_url(SRTLA_STREAM_ID),
                        "srt": {"adaptiveBitrateEnabled": False},
                        "bitrate": 5_000_000,
                    }
                ],
                "srtlaServer": {
                    "enabled": True,
                    "srtPort": SRT_SERVER_PORT,
                    "srtlaPort": SRTLA_SERVER_PORT,
                    "streams": [
                        {
                            "id": SRTLA_INGEST_ID,
                            "name": "Test",
                            "streamId": SRTLA_STREAM_ID,
                        }
                    ],
                },
            }
        )

    def run(self):
        self.moblin.set_scene(SceneName.FRONT)
        self.moblin.go_live()
        self.moblin.wait_for_bitrate(4_000_000, 6_000_000, None, 10_000_000)
        self.moblin.wait_for_bitrate_info(Range(4_000_000, 6_000_000), 10_000_000)
        self.moblin.wait_for_bonding_bytes_per_second(Range(500_000, 750_000))
        self.moblin.wait_for_ingests(
            bitrate=Range(4_000_000, 6_000_000),
            total_bytes=10_000_000,
            number_of_ingests=1,
        )
        self.moblin.end()


class StreamSrtlaBondingToMoblin(StreamTestCase):
    """SRTLA stream from Moblin over two network interfaces to Moblin on the tester machine."""

    def setup(self):
        self.skip_if_no_secondary_ip_address()
        self.skip_if_no_receiver()
        self.moblin.wait_for_tcp_ports(
            WEB_REMOTE_CONTROL_PORT,
            ip_address=self.moblin.secondary_ip_address,
        )
        self.import_stream_settings(
            url=self.moblin.tester_srtla_url(SRTLA_STREAM_ID),
            srt={"adaptiveBitrateEnabled": False},
            bitrate=5_000_000,
        )

    def run(self):
        with create_receiver(self.moblin.config) as receiver:
            receiver.import_settings(
                overrides={
                    "scenes": [
                        {
                            "cameraPosition": CameraPosition.SRTLA,
                            "srtlaCameraId": SRTLA_INGEST_ID,
                            "micId": mic_id(SRTLA_INGEST_ID),
                            "overrideMic": True,
                            "enabled": True,
                        }
                    ],
                    "srtlaServer": {
                        "enabled": True,
                        "srtPort": TESTER_SRTLA_SRT_PORT,
                        "srtlaPort": TESTER_SRTLA_PORT,
                        "streams": [
                            {
                                "id": SRTLA_INGEST_ID,
                                "name": "Test",
                                "streamId": SRTLA_STREAM_ID,
                            }
                        ],
                    },
                }
            )
            self.moblin.go_live()
            self.moblin.wait_for_bonding_connections(2)
            self.moblin.wait_for_bitrate(4_000_000, 6_000_000, None, 10_000_000)
            receiver.wait_for_ingests(
                bitrate=Range(4_000_000, 6_000_000),
                total_bytes=10_000_000,
                number_of_ingests=1,
            )
            self.moblin.end()


class StreamWhipToMediaMtx(StreamTestCase):
    """WHIP stream from Moblin to MediaMTX for a few seconds."""

    def setup(self):
        self.import_stream_settings(
            url=self.moblin.tester_whip_url("test"),
            codec=VideoCodec.H264,
            audioCodec=AudioCodec.OPUS,
            bitrate=5_000_000,
        )

    def run(self):
        with self.stream_to_mediamtx(4_500_000, 5_500_000, 10_000_000) as mediamtx:
            mediamtx.wait_for_webrtc_stream("test", 5_000_000)


class StreamMultiRtmpToMediaMtx(StreamTestCase):
    """Multiple RTMP streams from Moblin to MediaMTX for a few seconds."""

    def setup(self):
        moblin = self.moblin
        self.import_stream_settings(
            url=moblin.tester_rtmp_url("test1"),
            rtmp={"adaptiveBitrateEnabled": False},
            multiStreaming={
                "destinations": [
                    {
                        "name": "Test 2",
                        "url": moblin.tester_rtmp_url("test2"),
                        "enabled": True,
                    },
                    {
                        "name": "Test 3",
                        "url": moblin.tester_rtmp_url("test3"),
                        "enabled": True,
                    },
                ]
            },
        )

    def run(self):
        with self.stream_to_mediamtx(4_500_000, 5_500_000, 30_000_000, multi_streaming="x3") as mediamtx:
            mediamtx.wait_for_rtmp_stream("test1", 10_000_000)
            mediamtx.wait_for_rtmp_stream("test2", 10_000_000)
            mediamtx.wait_for_rtmp_stream("test3", 10_000_000)


@dataclass
class Offsets:
    recording: float
    stream: float


class StreamSrtToFfmpegVideoStabilizationSync(StreamTestCase):
    """Record and stream over SRT to the test runner computer with the back camera and video
    stabilization off, standard and cinematic, triggering a few alerts in each run. Validate that
    the alert audio is late relative to the alert video by roughly 0, 100 and 500 ms, respectively,
    in both the recording and the stream. The offset with video stabilization off is the reference,
    as it is not zero. Video stabilization delays the camera frames, and the alert is drawn on the
    delayed frame that is current when the alert fires, so the audio captured by the mic at that
    time is late relative to it by the video stabilization latency.

    """

    def __init__(self, moblin: Moblin):
        super().__init__(moblin)
        self._alert_times: list[float] = []

    def run(self):
        manual_volume_requirement(LOGGER)
        offsets = {mode: self._measure_offsets(mode) for mode in VIDEO_STABILIZATION_OFFSETS}
        reference = offsets[VideoStabilizationMode.OFF]
        for mode, measured in offsets.items():
            self._assert_offset(mode, "recording", measured.recording - reference.recording)
            self._assert_offset(mode, "stream", measured.stream - reference.stream)

    def _measure_offsets(self, video_stabilization_mode: VideoStabilizationMode) -> Offsets:
        self._import_settings(video_stabilization_mode)
        self.moblin.set_scene(SceneName.BACK)
        LOGGER.info("Recording and streaming with video stabilization '%s'.", video_stabilization_mode)
        file_name = f"{self.name}-{video_stabilization_mode.name.lower()}"
        stream_file = FILES_DIR / f"{file_name}.ts"
        recorder = Recorder(self.moblin, f"{file_name}.mp4")
        with FfmpegServer(url=srt_listener_url(), filename=stream_file):
            self.moblin.go_live()
            self.moblin.wait_for_bitrate(4_000_000, 6_000_000, None, 2_000_000)
            with recorder:
                self._trigger_alerts()
            self.moblin.end()
        return Offsets(
            recording=self._measure_offset(recorder.recording),
            stream=self._measure_offset(stream_file),
        )

    def _import_settings(self, video_stabilization_mode: VideoStabilizationMode):
        self.moblin.import_settings(
            overrides={
                "streams": [
                    {
                        **RECORD_STREAM_SETTINGS,
                        "bitrateRateControl": BitrateRateControl.CBR,
                        "url": self.moblin.tester_srt_publish_url("test"),
                        "srt": {"adaptiveBitrateEnabled": False},
                        "bitrate": 5_000_000,
                    }
                ],
                "scenes": [
                    {
                        **BACK_SCENE_SETTINGS,
                        "widgets": [
                            scene_widget_settings(
                                ALERT_WIDGET_ID,
                                x=ALERT_WIDGET_X,
                                y=ALERT_WIDGET_Y,
                                size=100,
                            )
                        ],
                    }
                ],
                "widgets": [alerts_widget_settings("Alert", ALERT_WIDGET_ID)],
                "alertsMediaGallery": alerts_media_gallery_settings(),
                "videoStabilizationMode": video_stabilization_mode,
                "chat": {
                    "botEnabled": True,
                    "botCommandPermissions": {"alert": {"moderatorsEnabled": True}, "migrated": True},
                    "timestampColorEnabled": True,
                },
            },
            files=alert_media_files(),
        )

    def _trigger_alerts(self):
        self._alert_times = []
        time.sleep(ALERT_DELAY)
        for _ in range(NUMBER_OF_ALERTS):
            self.moblin.send_chat_message(alert_chat_message())
            self._alert_times.append(time.monotonic())
            time.sleep(ALERT_INTERVAL)

    def _measure_offset(self, path: Path) -> float:
        report = measure_alert_synchronization(path, self._alert_times, ALERT_WIDGET_X, ALERT_WIDGET_Y)
        report.log()
        self.assert_equal(len(report.missing), 0)
        self.assert_less(report.spread(), MAXIMUM_OFFSET_SPREAD)
        offsets = report.offsets()
        return sum(offsets) / len(offsets)

    def _assert_offset(self, video_stabilization_mode: VideoStabilizationMode, kind: str, offset: float):
        LOGGER.debug(
            "Video stabilization '%s': the audio is %.0f ms later in the %s than without video "
            "stabilization.",
            video_stabilization_mode,
            1000 * offset,
            kind,
        )
        expected = VIDEO_STABILIZATION_OFFSETS[video_stabilization_mode]
        self.assert_less(abs(offset - expected), MAXIMUM_OFFSET_ERROR)


class StreamToGenericUrls(StreamTestCase):
    """Stream to each generic URL for a few seconds."""

    def __init__(self, moblin: Moblin, number: int, generic_stream_url: str):
        self._generic_stream = format_generic_stream_url_stream_name(number, generic_stream_url)
        super().__init__(moblin, f"StreamToGenericUrls({self._generic_stream})")
        self._generic_stream_url = generic_stream_url

    def setup(self):
        self.import_stream_settings(
            url=self._generic_stream_url,
            codec=VideoCodec.H264,
            bitrate=5_000_000,
        )

    def run(self):
        self.moblin.set_scene(SceneName.FRONT)
        self.moblin.go_live()
        self.moblin.wait_for_bitrate(4_000_000, 6_000_000, None, 10_000_000)
        self.moblin.end()


def tests(moblin: Moblin):
    return [
        StreamRtmpToMediaMtx(moblin),
        StreamSrtToMediaMtx(moblin),
        StreamSrtToFfmpeg(moblin, resolution=Resolution.FULL_HD, fps=30),
        StreamSrtToFfmpeg(moblin, resolution=Resolution.FULL_HD, fps=60),
        StreamSrtToFfmpeg(moblin, resolution=Resolution.QUAD_HD_4_3, fps=30),
        StreamSrtToFfmpegHighBitrate(moblin),
        StreamSrtToFfmpegEncrypted(moblin),
        StreamSrtToFfmpegTimecodes(moblin),
        StreamSrtToFfmpegVideoRateControl(moblin, BitrateRateControl.ABR),
        StreamSrtToFfmpegVideoRateControl(moblin, BitrateRateControl.CBR),
        StreamSrtToFfmpegVideoRateControl(moblin, BitrateRateControl.VBR),
        StreamRistToFfmpeg(moblin),
        StreamRistBondingToFfmpeg(moblin),
        StreamSrtlaToSelf(moblin),
        StreamSrtlaBondingToMoblin(moblin),
        StreamWhipToMediaMtx(moblin),
        StreamMultiRtmpToMediaMtx(moblin),
        StreamSrtToFfmpegVideoStabilizationSync(moblin),
    ] + [
        StreamToGenericUrls(moblin, number, generic_stream_url)
        for number, generic_stream_url in enumerate(moblin.config.generic_stream_urls(), 1)
    ]
