import logging
import time
from dataclasses import dataclass
from pathlib import Path

from ..utils.audio_video_sync import alert_chat_message
from ..utils.audio_video_sync import alert_media_files
from ..utils.audio_video_sync import alerts_media_gallery_settings
from ..utils.audio_video_sync import alerts_widget_settings
from ..utils.audio_video_sync import measure_alert_synchronization
from ..utils.config import srt_listener_url
from ..utils.ffmpeg import FfmpegServer
from ..utils.generate_device_settings import FRONT_SCENE_SETTINGS
from ..utils.generate_device_settings import RECORD_STREAM_SETTINGS
from ..utils.generate_device_settings import BitrateRateControl
from ..utils.generate_device_settings import SceneName
from ..utils.generate_device_settings import mics_settings
from ..utils.generate_device_settings import scene_widget_settings
from ..utils.generate_device_settings import uuid
from ..utils.moblin import Moblin
from ..utils.moblin import Recorder
from ..utils.test_case import TestCase
from ..utils.utils import FILES_DIR
from ..utils.utils import manual_validation

LOGGER = logging.getLogger(__name__)
ALERT_WIDGET_ID = uuid()
ALERT_WIDGET_X = 40.0
ALERT_WIDGET_Y = 40.0
REFERENCE_DELAY = 0.0
DELAYS = [REFERENCE_DELAY, 0.5, -0.5]
NUMBER_OF_ALERTS = 3
FIRST_ALERT_DELAY = 5
ALERT_INTERVAL = 7
STREAM_BITRATE = 5_000_000
MAXIMUM_OFFSET_ERROR = 0.15
MAXIMUM_OFFSET_SPREAD = 0.25
MINIMUM_NUMBER_OF_ALERTS = 2


@dataclass
class Offsets:
    recording: float
    stream: float


class MicDelay(TestCase):
    """Record and stream over SRT to the test runner computer with the selected mic delay set to
    0, 0.5 and -0.5 seconds, triggering a few alerts in each run, and validate that the audio is
    late by the mic delay relative to the video in both the recording and the stream. The offset
    without any mic delay is the reference, as it is not zero.

    """

    def __init__(self, moblin: Moblin):
        super().__init__(moblin)
        self._alert_times: list[float] = []

    def run(self):
        manual_validation(
            LOGGER,
            "Keep the volume turned up so the microphone picks up the alert sounds",
        )
        offsets = {delay: self._measure_offsets(delay) for delay in DELAYS}
        self._assert_offsets(offsets)

    def _measure_offsets(self, delay: float) -> Offsets:
        self._import_settings(delay)
        self.moblin.set_scene(SceneName.FRONT)
        LOGGER.debug("Recording and streaming with mic '%s' delayed %.2f s.", self.moblin.get_mic(), delay)
        stream_file = FILES_DIR / f"{self._file_name(delay)}.ts"
        recorder = Recorder(self.moblin, f"{self._file_name(delay)}.mp4")
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

    def _import_settings(self, delay: float):
        mics = self.moblin.get_mics()
        self.assert_greater(len(mics), 0)
        self.moblin.import_settings(
            overrides={
                "streams": [
                    {
                        **RECORD_STREAM_SETTINGS,
                        "bitrateRateControl": BitrateRateControl.CBR,
                        "url": self.moblin.tester_srt_publish_url("test"),
                        "srt": {"adaptiveBitrateEnabled": False},
                        "bitrate": STREAM_BITRATE,
                    }
                ],
                "scenes": [
                    {
                        **FRONT_SCENE_SETTINGS,
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
                "chat": {
                    "botEnabled": True,
                    "botCommandPermissions": {"alert": {"moderatorsEnabled": True}, "migrated": True},
                },
                "mics": mics_settings(mics, delay),
            },
            files=alert_media_files(),
        )

    def _trigger_alerts(self):
        self._alert_times = []
        time.sleep(FIRST_ALERT_DELAY)
        for _ in range(NUMBER_OF_ALERTS):
            self.moblin.send_chat_message(alert_chat_message())
            self._alert_times.append(time.monotonic())
            time.sleep(ALERT_INTERVAL)

    def _measure_offset(self, path: Path) -> float:
        report = measure_alert_synchronization(path, self._alert_times, ALERT_WIDGET_X, ALERT_WIDGET_Y)
        report.log()
        self.assert_greater_equal(len(report.alerts), MINIMUM_NUMBER_OF_ALERTS)
        self.assert_less(report.spread(), MAXIMUM_OFFSET_SPREAD)
        offsets = report.offsets()
        return sum(offsets) / len(offsets)

    def _assert_offsets(self, offsets: dict[float, Offsets]):
        reference = offsets[REFERENCE_DELAY]
        for delay, measured in offsets.items():
            self._assert_offset(delay, "recording", measured.recording - reference.recording)
            self._assert_offset(delay, "stream", measured.stream - reference.stream)

    def _assert_offset(self, delay: float, kind: str, offset: float):
        LOGGER.debug(
            "Mic delay %.2f s: the audio is %.0f ms later in the %s than without mic delay.",
            delay,
            1000 * offset,
            kind,
        )
        self.assert_less(abs(offset - delay), MAXIMUM_OFFSET_ERROR)

    def _file_name(self, delay: float) -> str:
        return f"{self.name}{delay:+.2f}s"


def tests(moblin: Moblin):
    return [MicDelay(moblin)]
