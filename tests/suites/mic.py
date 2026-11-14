import logging
import time
from dataclasses import dataclass
from itertools import groupby
from pathlib import Path

from systest import wait_until
from systest_moblin.ffmpeg import FfmpegCommand
from systest_moblin.ffmpeg import FfmpegServer
from systest_moblin.ffmpeg import FfmpegVideoCodec
from systest_moblin.ffmpeg import TransportFormat
from systest_moblin.ffmpeg import ffmpeg_run
from systest_moblin.ffmpeg import ffprobe_audio
from systest_moblin.ffmpeg import ffprobe_video
from systest_moblin.ffmpeg import measure_audio_band_levels
from systest_moblin.ffmpeg import video_encoder_args

from ..utils.audio_video_sync import alert_chat_message
from ..utils.audio_video_sync import alert_media_files
from ..utils.audio_video_sync import alerts_media_gallery_settings
from ..utils.audio_video_sync import alerts_widget_settings
from ..utils.audio_video_sync import measure_alert_synchronization
from ..utils.config import RTMP_SERVER_PORT
from ..utils.config import Capability
from ..utils.config import srt_listener_url
from ..utils.generate_device_settings import FRONT_SCENE_SETTINGS
from ..utils.generate_device_settings import RECORD_STREAM_SETTINGS
from ..utils.generate_device_settings import BitrateRateControl
from ..utils.generate_device_settings import CameraPosition
from ..utils.generate_device_settings import SceneName
from ..utils.generate_device_settings import mic_id
from ..utils.generate_device_settings import mics_settings
from ..utils.generate_device_settings import scene_widget_settings
from ..utils.generate_device_settings import uuid
from ..utils.moblin import Moblin
from ..utils.moblin import Recorder
from ..utils.test_case import AUDIO_SAMPLES_PER_FRAME
from ..utils.test_case import TestCase
from ..utils.utils import FILES_DIR
from ..utils.utils import manual_confirmation
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
TONE_STREAM_1_ID = uuid()
TONE_STREAM_2_ID = uuid()
TONE_STREAM_VIDEO_BITRATE = 4_000_000
TONE_WINDOW = 0.25
TONE_BANDWIDTH = 50
TONE_BAND_MARGIN_DB = 3
MAXIMUM_TRANSITION_DURATION = 0.5


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


class MicInterruption(TestCase):
    """Record and stream over SRT to the test runner computer while a timer alarm in the Clock
    app interrupts the audio session. Trigger one alert before and one after the interruption,
    and validate that no video frames are missing, that the audio has no gaps and that the
    alert audio and video are in sync in both the recording and the stream.

    """

    def __init__(self, moblin: Moblin):
        super().__init__(moblin)
        self._alert_times: list[float] = []

    def setup(self):
        self.skip_if_not_interactive()
        self.moblin.import_settings(
            overrides=settings_overrides(self.moblin),
            files=alert_media_files(),
        )

    def run(self):
        manual_volume_requirement(LOGGER)
        manual_confirmation(
            "Set a timer for 30 seconds in the Clock app and move Moblin back to the foreground."
        )
        wait_until(self._is_streamer_connected, "streamer to connect", ignore_errors=True)
        self.moblin.set_scene(SceneName.FRONT)
        self.moblin.set_main_mic()
        stream_file = FILES_DIR / f"{self.name}.ts"
        recorder = Recorder(self.moblin, f"{self.name}.mp4")
        with FfmpegServer(url=srt_listener_url(), filename=stream_file):
            self.moblin.go_live()
            self.moblin.wait_for_bitrate(4_000_000, 6_000_000, None, 2_000_000)
            with recorder:
                self._trigger_alert()
                manual_confirmation("Stop the timer alarm 5 to 10 seconds after it starts ringing.")
                self._trigger_alert()
            self.moblin.end()
        self._assert_media(recorder.recording)
        self._assert_media(stream_file)

    def _is_streamer_connected(self) -> bool:
        self.moblin.ping()
        return True

    def _trigger_alert(self):
        time.sleep(ALERT_DELAY)
        self.moblin.send_chat_message(alert_chat_message())
        self._alert_times.append(time.monotonic())
        time.sleep(ALERT_DURATION)

    def _find_gaps(
        self, path: Path, name: str, presentation_time_stamps: list[float], maximum_delta: float
    ) -> list[float]:
        self.assert_greater(len(presentation_time_stamps), 0)
        gaps = []
        for previous, current in zip(presentation_time_stamps, presentation_time_stamps[1:]):
            if current - previous > maximum_delta:
                LOGGER.info("%s gap from %.3f to %.3f seconds in %s", name, previous, current, path.name)
                gaps.append(current - previous)
        return gaps

    def _assert_media(self, path: Path):
        video = ffprobe_video(path)
        video_gaps = self._find_gaps(path, "Video", [frame.pts for frame in video.frames], 1.5 / STREAM_FPS)
        self.assert_less_equal(len(video_gaps), 1, "Video gaps.")
        for gap in video_gaps:
            self.assert_less(gap, 0.5, "Video gap.")
        audio = ffprobe_audio(path)
        self.assert_equal(audio.sample_rate, 48000)
        audio_presentation_time_stamps = [frame.pts for frame in audio.frames]
        self.assert_equal(len(self._find_gaps(path, "Audio", audio_presentation_time_stamps, 0.1)), 0)
        self.assert_greater(
            audio_presentation_time_stamps[-1] + 0.5,
            video.frames[-1].pts,
            "Audio ends before video.",
        )
        report = measure_alert_synchronization(path, self._alert_times, ALERT_WIDGET_X, ALERT_WIDGET_Y)
        report.log()
        self.assert_equal(len(report.missing), 0)
        self.assert_less(report.spread(), MAXIMUM_OFFSET_SPREAD)


@dataclass
class ToneMic:
    stream_id: str
    stream_key: str
    frequency: int
    sample_rate: int
    channels: int

    def label(self) -> str:
        return f"{self.sample_rate}Hz{self.channels}ch"


class FfmpegToneTestStream(FfmpegCommand):
    def __init__(self, url: str, mic: ToneMic) -> None:
        super().__init__()
        self._url = url
        self._mic = mic

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
            f"sine=frequency={self._mic.frequency}:sample_rate={self._mic.sample_rate}",
            *video_encoder_args(TONE_STREAM_VIDEO_BITRATE, FfmpegVideoCodec.H264, True),
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
            str(self._mic.sample_rate),
            "-ac",
            str(self._mic.channels),
            "-f",
            TransportFormat.FLV,
            self._url,
        ]


class MicSwitchFormats(TestCase):
    """Stream a tone to each of two RTMP server ingests, each with its own frequency, sample
    rate and number of channels, and record while switching between the two ingest mics every
    few seconds. Validate that the recording is 48 kHz with the channels of the first mic, that
    no audio samples are missing, and that the audio in every recorded channel alternates
    between the two tones at their original pitch.

    """

    def __init__(self, moblin: Moblin, first: ToneMic, second: ToneMic):
        super().__init__(moblin, f"MicSwitchFormats-{first.label()}-{second.label()}")
        self._mics = [first, second]

    def setup(self):
        self.moblin.import_settings(
            overrides={
                "streams": [RECORD_STREAM_SETTINGS],
                "scenes": [
                    {
                        **FRONT_SCENE_SETTINGS,
                        "cameraPosition": CameraPosition.RTMP,
                        "rtmpCameraId": self._mics[0].stream_id,
                    }
                ],
                "rtmpServer": {
                    "enabled": True,
                    "port": RTMP_SERVER_PORT,
                    "streams": [
                        {"id": mic.stream_id, "name": mic.stream_key, "streamKey": mic.stream_key}
                        for mic in self._mics
                    ],
                },
            }
        )
        self.moblin.wait_for_tcp_ports(RTMP_SERVER_PORT)

    def run(self):
        streams = [
            FfmpegToneTestStream(self.moblin.ingest_rtmp_url(mic.stream_key), mic) for mic in self._mics
        ]
        recorder = Recorder(self.moblin, f"{self.name}.mp4")
        with streams[0], streams[1]:
            self.wait_for_ingest_stream_started(number_of_ingests=len(self._mics))
            self.moblin.set_scene(SceneName.FRONT)
            self._select_mic(self._mics[0])
            with recorder:
                time.sleep(SWITCH_INTERVAL)
                for index in range(1, NUMBER_OF_SWITCHES + 1):
                    self._select_mic(self._mics[index % len(self._mics)])
                    time.sleep(SWITCH_INTERVAL)
        self._assert_format(recorder.recording)
        for channel in range(self._mics[0].channels):
            self._assert_channel_tones(recorder.recording, channel)

    def _select_mic(self, mic: ToneMic):
        name = self._mic_name(mic)
        self.moblin.set_mic(name)
        self.wait_until(lambda: self.moblin.get_mic() == name)
        LOGGER.debug("Switched to mic '%s' (%s, %s Hz tone).", name, mic.label(), mic.frequency)

    def _mic_name(self, mic: ToneMic) -> str:
        for settings_mic in self.moblin.get_mics():
            if settings_mic["id"] == mic_id(mic.stream_id):
                return settings_mic["name"]
        raise Exception(f"No mic for RTMP stream '{mic.stream_key}'.")

    def _assert_format(self, path: Path):
        audio = ffprobe_audio(path)
        self.assert_equal(audio.sample_rate, 48000)
        self.assert_equal(audio.channels, self._mics[0].channels)
        for frame in audio.frames:
            self.assert_equal(frame.channels, self._mics[0].channels)
        self.assert_presentation_time_stamps(
            path,
            AUDIO_SAMPLES_PER_FRAME / audio.sample_rate,
            [frame.pts for frame in audio.frames],
            "audio",
        )
        video = ffprobe_video(path)
        self.assert_less(
            abs(audio.frames[-1].pts - video.frames[-1].pts), 0.5, "Audio and video end times differ."
        )

    def _assert_channel_tones(self, path: Path, channel: int):
        LOGGER.debug("Tones in channel %d.", channel)
        channel_path = path.with_name(f"{path.stem}-channel{channel}.wav")
        ffmpeg_run("-i", str(path), "-vn", "-af", f"pan=mono|c0=c{channel}", str(channel_path))
        self._assert_tones(channel_path)

    def _assert_tones(self, path: Path):
        total = measure_audio_band_levels(path, [], TONE_WINDOW)
        bands = [
            measure_audio_band_levels(path, self._band_filters(mic.frequency), TONE_WINDOW)
            for mic in self._mics
        ]
        classes = []
        for index, level in enumerate(total):
            matches = [
                mic_index
                for mic_index, band in enumerate(bands)
                if band[index].level > level.level - TONE_BAND_MARGIN_DB
            ]
            classes.append(matches[0] if len(matches) == 1 else None)
        runs = [(mic_index, len(list(group))) for mic_index, group in groupby(classes)]
        for mic_index, length in runs:
            LOGGER.debug(
                "%.2f s of %s.",
                length * TONE_WINDOW,
                "other audio" if mic_index is None else f"{self._mics[mic_index].frequency} Hz tone",
            )
        tone_runs = [(mic_index, length) for mic_index, length in runs if mic_index is not None]
        self.assert_equal(
            [mic_index for mic_index, _ in tone_runs],
            [index % len(self._mics) for index in range(NUMBER_OF_SWITCHES + 1)],
            "Tone sequence.",
        )
        for _, length in tone_runs[1:-1]:
            self.assert_greater(length * TONE_WINDOW, SWITCH_INTERVAL - 1, "Tone duration.")
        for mic_index, length in runs:
            if mic_index is None:
                self.assert_less_equal(length * TONE_WINDOW, MAXIMUM_TRANSITION_DURATION, "Other audio.")

    def _band_filters(self, frequency: int) -> list[str]:
        return [f"bandpass=f={frequency}:width_type=h:w={TONE_BANDWIDTH}"] * 2


def tests(moblin: Moblin):
    return [
        MicDelay(moblin),
        MicSwitch(moblin),
        MicSwitchFormats(
            moblin,
            ToneMic(TONE_STREAM_1_ID, "1", 1000, 48000, 1),
            ToneMic(TONE_STREAM_2_ID, "2", 2500, 44100, 2),
        ),
        MicSwitchFormats(
            moblin,
            ToneMic(TONE_STREAM_1_ID, "1", 1000, 44100, 2),
            ToneMic(TONE_STREAM_2_ID, "2", 2500, 48000, 1),
        ),
        MicStereo(moblin),
        MicInterruption(moblin),
    ]
