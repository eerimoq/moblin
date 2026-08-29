import logging
import re
import statistics
import subprocess
import time
from collections.abc import Callable
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from datetime import datetime
from fractions import Fraction
from pathlib import Path

import systest
from systest import wait_until

from .common.ffmpeg import Crop
from .common.ffmpeg import FfmpegVideoCodec
from .common.ffmpeg import FfprobeAudioOutput
from .common.ffmpeg import FfprobeFormatOutput
from .common.ffmpeg import FfprobeVideoOutput
from .common.ffmpeg import Image
from .common.ffmpeg import QrCode
from .common.ffmpeg import detect_silence
from .common.ffmpeg import extract_ltc_wav
from .common.ffmpeg import ffprobe
from .common.ffmpeg import ffprobe_audio
from .common.ffmpeg import ffprobe_format
from .common.ffmpeg import ffprobe_video
from .common.ffmpeg import ffprobe_video_size
from .common.ffmpeg import measure_mean_volume
from .common.ffmpeg import read_qr_codes
from .common.ffmpeg import read_unique_frame_presentation_time_stamps
from .common.ffmpeg import read_video_timecodes
from .config import Capability
from .moblin import Moblin
from .utils import FILES_DIR
from .utils import Range
from .utils import anchor_time_of_day

LOGGER = logging.getLogger(__name__)
RE_LTCDUMP = re.compile(r"\S+\s+00:(\d+):(\d+):.*")
CHANNEL_LAYOUTS = {1: "mono", 2: "stereo"}
AUDIO_SAMPLES_PER_FRAME = 1024


class TestCase(systest.TestCase):
    def __init__(self, moblin: Moblin, name: str | None = None):
        super().__init__(name)
        self.moblin = moblin

    def teardown(self):
        self.moblin.end()
        self.moblin.stop_recording()
        self.moving_picture_off()

    def skip_if_missing_capability(self, capability: Capability):
        if not self.moblin.has_capability(capability):
            raise systest.TestCaseSkippedError(f"{capability} capability missing.")

    def skip_if_no_secondary_ip_address(self):
        if not self.moblin.has_secondary_ip_address():
            raise systest.TestCaseSkippedError("No secondary IP address.")

    def skip_if_no_receiver(self):
        if not self.moblin.config.has_receiver():
            raise systest.TestCaseSkippedError("No receiver.")

    def skip_if_no_moving_picture(self):
        if not self.moblin.has_moving_picture():
            raise systest.TestCaseSkippedError("No moving picture.")

    def skip_if_no_dji_camera(self):
        if not self.moblin.has_dji_camera():
            raise systest.TestCaseSkippedError("No DJI camera.")

    def skip_if_not_interactive(self):
        if not self.moblin.is_interactive():
            raise systest.TestCaseSkippedError("Not interactive.")

    def moving_picture_on(self):
        if self.moblin.arduino is None:
            return
        self.moblin.arduino.back_motor_on()
        self.moblin.arduino.front_motor_on()

    def moving_picture_off(self):
        if self.moblin.arduino is None:
            return
        self.moblin.arduino.back_motor_off()
        self.moblin.arduino.front_motor_off()

    def wait_for_ingest_stream_started(self, number_of_ingests=1, startup_delay=1):
        time.sleep(startup_delay)
        self.moblin.wait_for_ingests(
            bitrate=Range(0, 100_000_000),
            total_bytes=3_000_000,
            number_of_ingests=number_of_ingests,
        )

    def assert_live_stream(
        self,
        recording: Path,
        minimum_length: float | None = 7,
        maximum_length: float | None = 20,
        width: int = 1920,
        height: int = 1080,
        fps: int = 30,
    ):
        metadata = ffprobe(recording)
        if minimum_length is not None:
            self.assert_greater(metadata.format.duration, minimum_length, "Minimum live stream length.")
        if maximum_length is not None:
            self.assert_less(metadata.format.duration, maximum_length, "Maximum live stream length.")
        self._assert_live_stream_video(metadata.video, width, height, fps)
        self._assert_live_stream_audio(metadata.audio)

    def _assert_live_stream_video(self, video: FfprobeVideoOutput, width: int, height: int, fps: int):
        self.assert_equal(video.codec, FfmpegVideoCodec.HEVC)
        self.assert_equal(video.width, width)
        self.assert_equal(video.height, height)
        self.assert_fps(video.real_base_fps, fps)

    def _assert_live_stream_audio(self, audio: FfprobeAudioOutput):
        self.assert_equal(audio.codec, "aac")

    def assert_recording(
        self,
        recording: Path,
        has_qr_codes: bool = True,
        duplicated_frames_crops: list[Crop] | None = None,
        has_audio_time_codes: bool = False,
        width: int = 1920,
        height: int = 1080,
        fps: int = 30,
        video_codec: FfmpegVideoCodec = FfmpegVideoCodec.HEVC,
        channels: int = 1,
    ):
        probe = probe_recording(recording, has_qr_codes, duplicated_frames_crops, has_audio_time_codes)
        self.assert_greater(probe.format.duration, 8, "Minimum recording length.")
        self.assert_less(probe.format.duration, 14, "Maximum recording length.")
        self._assert_video(probe, recording, width, height, fps, video_codec)
        self._assert_audio(probe, recording, channels)

    def assert_timecodes(self, recording: Path, start: datetime, end: datetime, fps: int = 30):
        timecodes = read_video_timecodes(recording)
        first = next((index for index, timecode in enumerate(timecodes) if timecode is not None), None)
        if first is None:
            raise Exception("No SEI timecodes in the stream.")
        self.assert_less(first, 2 * fps, "Frames before the first SEI timecode.")
        present = [timecode for timecode in timecodes[first:] if timecode is not None]
        self.assert_equal(len(present), len(timecodes) - first, "Frames with a SEI timecode.")
        offsets = []
        for timecode in present:
            self.assert_less(timecode.frame, fps, "SEI timecode frame number.")
            timecode_time = anchor_time_of_day(timecode.time_of_day(fps), start)
            self.assert_greater(timecode_time, start.timestamp() - 2, "SEI timecode before the stream.")
            self.assert_less(timecode_time, end.timestamp() + 2, "SEI timecode after the stream.")
            offsets.append(timecode_time - timecode.pts)
        median = statistics.median(offsets)
        spread = max(abs(offset - median) for offset in offsets)
        drift = statistics.median(offsets[-fps:]) - statistics.median(offsets[:fps])
        LOGGER.debug(
            "SEI timecodes: %s of %s frames, spread %.3f s, drift %.3f s",
            len(present),
            len(timecodes),
            spread,
            drift,
        )
        self.assert_less(spread, 0.25, "SEI timecode spread.")
        self.assert_less(abs(drift), 2 / fps, "SEI timecode drift.")

    def assert_no_audio_glitches(self, recording: Path):
        audio = ffprobe_audio(recording)
        self.assert_equal(audio.sample_rate, 48000)
        self._assert_audio_presentation_time_stamps(recording, audio)
        mean_volume_db = measure_mean_volume(recording)
        LOGGER.debug("Mean volume: %.1f dB", mean_volume_db)
        self.assert_greater(
            mean_volume_db,
            -55,
            "The played noise was not picked up by the microphone. Turn up the volume of the device.",
        )
        dropouts = [
            dropout for dropout in detect_silence(recording, mean_volume_db - 25, 0.1) if dropout.start > 0
        ]
        for dropout in dropouts:
            LOGGER.info("Audio dropout from %.3f to %.3f seconds", dropout.start, dropout.end)
        self.assert_equal(len(dropouts), 0)

    def assert_fps(self, actual: Fraction | None, fps: int):
        if actual is None:
            raise Exception(f"No frame rate reported by ffprobe. Expected {fps}.")
        self.assert_greater(actual, Fraction(f"{fps - 1}/1"))
        self.assert_less(actual, Fraction(f"{fps + 1}/1"))

    def assert_video_size(self, recording: Path, width: int, height: int):
        self.assert_equal(ffprobe_video_size(recording), (width, height))

    def assert_all_black(self, image: Image):
        if image.is_all_black():
            return
        position = image.find_non_black_pixel() or (-1, -1)
        raise Exception(f"Pixel at {position} is {image.pixel(*position)}, but expected it to be black.")

    def assert_not_all_black(self, image: Image, minimum_ratio: float = 0.01):
        self.assert_greater(image.non_black_ratio(), minimum_ratio)

    def wait_until(self, check: Callable[[], bool]):
        wait_until(check, "condition to be true")

    def _assert_video(
        self,
        probe: "RecordingProbe",
        recording: Path,
        width,
        height,
        fps: int,
        video_codec: FfmpegVideoCodec,
    ):
        video = probe.video
        self.assert_equal(video.codec, video_codec)
        self.assert_equal(video.width, width)
        self.assert_equal(video.height, height)
        self.assert_fps(video.average_fps, fps)
        self.assert_presentation_time_stamps(
            recording, 1 / fps, [frame.pts for frame in video.frames], "video"
        )
        self._assert_video_frame_numbers_increasing(probe.qr_codes)
        picture_types = {frame.picture_type for frame in video.frames}
        self.assert_equal(len(picture_types), 3)
        self.assert_in("I", picture_types)
        self.assert_in("P", picture_types)
        self.assert_in("B", picture_types)
        for presentation_time_stamps in probe.unique_frame_presentation_time_stamps:
            self._assert_no_duplicated_frames(fps, video, recording, presentation_time_stamps)

    def _assert_no_duplicated_frames(
        self,
        fps: int,
        video: FfprobeVideoOutput,
        recording: Path,
        presentation_time_stamps: list[float],
    ):
        self.assert_presentation_time_stamps(recording, 1 / fps, presentation_time_stamps, "video")
        self.assert_equal(len(presentation_time_stamps), len(video.frames))

    def _assert_audio(self, probe: "RecordingProbe", recording: Path, channels: int):
        audio = probe.audio
        self.assert_equal(audio.codec, "aac")
        self.assert_equal(audio.profile, "LC")
        self.assert_equal(audio.sample_rate, 48000)
        self.assert_equal(audio.channels, channels)
        self.assert_equal(audio.channel_layout, CHANNEL_LAYOUTS[channels])
        self.assert_greater(audio.bit_rate, 115_000)
        self.assert_less(audio.bit_rate, 136_000)
        self._assert_audio_presentation_time_stamps(recording, audio)
        self._assert_audio_time_codes(probe.audio_time_codes)
        for frame in audio.frames:
            self.assert_equal(frame.channels, channels)
            self.assert_equal(frame.number_of_samples, AUDIO_SAMPLES_PER_FRAME)

    def _assert_audio_presentation_time_stamps(self, recording: Path, audio: FfprobeAudioOutput):
        self.assert_presentation_time_stamps(
            recording,
            AUDIO_SAMPLES_PER_FRAME / audio.sample_rate,
            [frame.pts for frame in audio.frames],
            "audio",
        )

    def assert_presentation_time_stamps(
        self,
        recording: Path,
        expected_delta: float,
        presentation_time_stamps: list[float],
        name: str,
        delta_error: float = 0.002,
    ):
        self.assert_greater(len(presentation_time_stamps), 0)
        missing_presentation_time_stamps = find_missing_presentation_time_stamps(
            expected_delta, presentation_time_stamps, delta_error
        )
        if len(missing_presentation_time_stamps) > 0:
            LOGGER.info(
                'Watch video: mpv --osd-msg1="PTS: \\${time-pos/full}" %s',
                recording.absolute(),
            )
            for time_stamp, delta in missing_presentation_time_stamps:
                LOGGER.info("%s: Missing PTS: %s (Delta: %s)", name, time_stamp, delta)
        self.assert_equal(
            len(missing_presentation_time_stamps), 0, f"for {name}. Expected delta: {expected_delta}"
        )

    def _assert_video_frame_numbers_increasing(self, qr_codes: list[QrCode] | None):
        if qr_codes is None:
            return
        self.assert_greater(len(qr_codes), 0)
        seen_increase = False
        bad_frame_numbers = False
        for index in range(1, len(qr_codes)):
            current = qr_codes[index].number
            previous = qr_codes[index - 1].number
            if current == previous:
                if seen_increase:
                    raise Exception(f"Frame number {current} already seen.")
            elif current == previous + 1:
                seen_increase = True
            else:
                LOGGER.info("Bad frame - Current: %s, Previous: %s", current, previous)
                bad_frame_numbers = True
        self.assert_false(bad_frame_numbers)

    def _assert_audio_time_codes(self, output: str | None):
        if output is None:
            return
        has_seen_start_time = False
        has_seen_end_time = False
        for line in output.splitlines():
            mo = RE_LTCDUMP.match(line)
            if mo:
                seconds = 60 * int(mo.group(1)) + int(mo.group(2))
                if 2 <= seconds <= 3:
                    has_seen_start_time = True
                if 9 <= seconds <= 10:
                    has_seen_end_time = True
            elif "#DISCONTINUITY" in line:
                if has_seen_start_time and not has_seen_end_time:
                    self._log_output(output)
                    raise Exception("Discontinuity in audio!")
        if not has_seen_start_time:
            self._log_output(output)
            raise Exception("Start time not found in audio!")
        if not has_seen_end_time:
            self._log_output(output)
            raise Exception("End time not found in audio!")

    def _log_output(self, output: str):
        for line in output.splitlines():
            LOGGER.info("ltcdump: %s", line)


@dataclass
class RecordingProbe:
    format: FfprobeFormatOutput
    video: FfprobeVideoOutput
    audio: FfprobeAudioOutput
    qr_codes: list[QrCode] | None
    unique_frame_presentation_time_stamps: list[list[float]]
    audio_time_codes: str | None


def probe_recording(
    recording: Path,
    has_qr_codes: bool,
    duplicated_frames_crops: list[Crop] | None,
    has_audio_time_codes: bool,
) -> RecordingProbe:
    crops = duplicated_frames_crops if duplicated_frames_crops is not None else [None]
    with ThreadPoolExecutor() as executor:
        format_future = executor.submit(ffprobe_format, recording)
        video_future = executor.submit(ffprobe_video, recording)
        audio_future = executor.submit(ffprobe_audio, recording)
        qr_codes_future = executor.submit(_read_qr_codes, recording, has_qr_codes)
        unique_frames_futures = [
            executor.submit(read_unique_frame_presentation_time_stamps, recording, crop) for crop in crops
        ]
        audio_time_codes_future = executor.submit(_read_audio_time_codes, recording, has_audio_time_codes)
        return RecordingProbe(
            format=format_future.result(),
            video=video_future.result(),
            audio=audio_future.result(),
            qr_codes=qr_codes_future.result(),
            unique_frame_presentation_time_stamps=[future.result() for future in unique_frames_futures],
            audio_time_codes=audio_time_codes_future.result(),
        )


def _read_qr_codes(recording: Path, has_qr_codes: bool) -> list[QrCode] | None:
    if not has_qr_codes:
        return None
    return read_qr_codes(recording, Crop(x=150, y=0, width=400, height=400))


def _read_audio_time_codes(recording: Path, has_audio_time_codes: bool) -> str | None:
    if not has_audio_time_codes:
        return None
    ltc_wav = FILES_DIR / "ltc.wav"
    extract_ltc_wav(recording, ltc_wav)
    return subprocess.run(
        ["ltcdump", "--fps", "30", str(ltc_wav)],
        check=True,
        capture_output=True,
        text=True,
    ).stdout


def find_missing_presentation_time_stamps(
    expected_delta: float, presentation_time_stamps: list[float], delta_error: float
) -> list[tuple[float, float]]:
    missing_presentation_time_stamps = []
    for index in range(1, len(presentation_time_stamps)):
        current = presentation_time_stamps[index]
        previous = presentation_time_stamps[index - 1]
        delta = current - previous
        if delta < expected_delta - delta_error or delta > expected_delta + delta_error:
            missing_presentation_time_stamps.append((current, delta))
    return missing_presentation_time_stamps
