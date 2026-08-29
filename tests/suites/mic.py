import logging
import time
from dataclasses import dataclass
from pathlib import Path

from ..utils.audio_video_sync import alert_chat_message
from ..utils.audio_video_sync import alert_media_files
from ..utils.audio_video_sync import alerts_media_gallery_settings
from ..utils.audio_video_sync import alerts_widget_settings
from ..utils.audio_video_sync import measure_alert_synchronization
from ..utils.common.ffmpeg import FfmpegServer
from ..utils.common.ffmpeg import ffprobe_audio
from ..utils.common.ffmpeg import ffprobe_video
from ..utils.config import Capability
from ..utils.config import srt_listener_url
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
from ..utils.utils import manual_volume_requirement

LOGGER = logging.getLogger(__name__)
ALERT_WIDGET_ID = uuid()
ALERT_WIDGET_X = 40.0
ALERT_WIDGET_Y = 40.0
STREAM_BITRATE = 5_000_000
MAXIMUM_OFFSET_SPREAD = 0.15
ALERT_DELAY = 5
REFERENCE_DELAY = 0.0
DELAYS = [REFERENCE_DELAY, 0.5, -0.5]
NUMBER_OF_ALERTS = 3
ALERT_INTERVAL = 7
MAXIMUM_OFFSET_ERROR = 0.15
MINIMUM_NUMBER_OF_ALERTS = 2
STREAM_FPS = 30
NUMBER_OF_MICS = 2
NUMBER_OF_SWITCHES = 10
SWITCH_INTERVAL = 3
ALERT_DURATION = 7


def settings_overrides(moblin: Moblin) -> dict:
    return {
        "streams": [
            {
                **RECORD_STREAM_SETTINGS,
                "bitrateRateControl": BitrateRateControl.CBR,
                "url": moblin.tester_srt_publish_url("test"),
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
            "timestampColorEnabled": True,
        },
    }


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
        manual_volume_requirement(LOGGER)
        offsets = {delay: self._measure_offsets(delay) for delay in DELAYS}
        self._assert_offsets(offsets)

    def _measure_offsets(self, delay: float) -> Offsets:
        self._import_settings(delay)
        self.moblin.set_scene(SceneName.FRONT)
        LOGGER.info("Recording and streaming with mic '%s' delayed %.2f s.", self.moblin.get_mic(), delay)
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
                **settings_overrides(self.moblin),
                "mics": mics_settings(mics, delay),
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


class MicSwitch(TestCase):
    """Record and stream over SRT to the test runner computer while switching between the two
    first mics every few seconds. Trigger one alert before the first mic switch and one after
    the last mic switch, and validate that no video frames or audio samples are missing and
    that the alert audio and video are in sync in both the recording and the stream.

    """

    def __init__(self, moblin: Moblin):
        super().__init__(moblin)
        self._mics: list[dict] = []
        self._alert_times: list[float] = []

    def setup(self):
        self.skip_if_missing_capability(Capability.DUAL_MICS)
        self.moblin.import_settings(
            overrides=settings_overrides(self.moblin),
            files=alert_media_files(),
        )

    def run(self):
        manual_volume_requirement(LOGGER)
        self._mics = self.moblin.get_mics()[:NUMBER_OF_MICS]
        self.assert_equal(len(self._mics), NUMBER_OF_MICS)
        self.moblin.set_scene(SceneName.FRONT)
        self.moblin.set_main_mic()
        stream_file = FILES_DIR / f"{self.name}.ts"
        recorder = Recorder(self.moblin, f"{self.name}.mp4")
        with FfmpegServer(url=srt_listener_url(), filename=stream_file):
            self.moblin.go_live()
            self.moblin.wait_for_bitrate(4_000_000, 6_000_000, None, 2_000_000)
            with recorder:
                self._trigger_alert()
                self._switch_mics()
                self._trigger_alert()
            self.moblin.end()
        self._assert_media(recorder.recording)
        self._assert_media(stream_file)

    def _switch_mics(self):
        selected = []
        for index in range(NUMBER_OF_SWITCHES):
            self.moblin.set_mic(self._mics[index % NUMBER_OF_MICS]["name"])
            time.sleep(SWITCH_INTERVAL)
            selected.append(self.moblin.get_mic())
            LOGGER.debug("Switched to mic '%s'.", selected[-1])
        self.assert_equal(len(set(selected)), NUMBER_OF_MICS)

    def _trigger_alert(self):
        self.moblin.set_main_mic()
        time.sleep(ALERT_DELAY)
        self.moblin.send_chat_message(alert_chat_message())
        self._alert_times.append(time.monotonic())
        time.sleep(ALERT_DURATION)

    def _assert_media(self, path: Path):
        self._assert_nothing_missing(path)
        self._assert_alerts_synchronized(path)

    def _assert_nothing_missing(self, path: Path):
        video = ffprobe_video(path)
        self.assert_presentation_time_stamps(
            path, 1 / STREAM_FPS, [frame.pts for frame in video.frames], "video"
        )
        audio = ffprobe_audio(path)
        self.assert_equal(audio.sample_rate, 48000)
        # self.assert_presentation_time_stamps(
        #     path,
        #     AUDIO_SAMPLES_PER_FRAME / audio.sample_rate,
        #     [frame.pts for frame in audio.frames],
        # )

    def _assert_alerts_synchronized(self, path: Path):
        report = measure_alert_synchronization(path, self._alert_times, ALERT_WIDGET_X, ALERT_WIDGET_Y)
        report.log()
        self.assert_equal(len(report.missing), 0)
        self.assert_less(report.spread(), MAXIMUM_OFFSET_SPREAD)


class MicStereo(TestCase):
    """Record a 10 seconds video with prefer stereo mic enabled and the front or back built-in
    mic selected, and validate that the recorded audio is stereo.

    """

    def setup(self):
        self.skip_if_missing_capability(Capability.STEREO_MIC)
        self.moblin.import_settings(
            overrides={
                "streams": [RECORD_STREAM_SETTINGS],
                "audio": {"preferStereoMic": True},
            }
        )

    def run(self):
        self.moblin.set_mic("Front")
        self.wait_until(lambda: self.moblin.get_number_of_audio_channels() == 2)
        recording = self.moblin.record(10, f"{self.name}.mp4")
        self.assert_recording(
            recording, FILES_DIR, has_qr_codes=False, duplicated_frames_crops=[], channels=2
        )


def tests(moblin: Moblin):
    return [
        MicDelay(moblin),
        MicSwitch(moblin),
        MicStereo(moblin),
    ]
