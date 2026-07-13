import logging
import re
import subprocess
import time
from collections.abc import Callable
from fractions import Fraction
from pathlib import Path
from typing import List

import systest

from .ffmpeg import FfprobeAudioOutput
from .ffmpeg import FfprobeVideoOutput
from .ffmpeg import extract_ltc_wav
from .ffmpeg import ffprobe
from .ffmpeg import ffprobe_video
from .ffmpeg import read_qr_codes
from .ffmpeg import remove_duplicated_frames
from .moblin import Moblin
from .utils import Crop

LOGGER = logging.getLogger(__name__)
RE_LTCDUMP = re.compile(r"\S+\s+00:(\d+):(\d+):.*")


class TestCase(systest.TestCase):
    def __init__(self, moblin: Moblin, name: str | None = None):
        super().__init__(name)
        self.moblin = moblin

    def teardown(self):
        self.moblin.end()
        self.moblin.stop_recording()

    def skip_if_missing_capability(self, name):
        if not self.moblin.has_capability(name):
            raise systest.TestCaseSkippedError(f"{name} capability missing.")

    def wait_for_ingest_stream_started(self, number_of_ingests=4, startup_delay=1):
        time.sleep(startup_delay)
        self.moblin.wait_for_ingests(
            minimim_bitrate=0,
            maximum_bitrate=100_000_000,
            total_bytes=3_000_000,
            number_of_ingests=number_of_ingests,
        )

    def assert_live_stream(
        self,
        recording: Path,
        minimum_length: int = 8,
        maximum_length: int = 20,
        fps: int = 30,
    ):
        metadata = ffprobe(recording)
        self.assert_greater(metadata.format.duration, minimum_length)
        self.assert_less(metadata.format.duration, maximum_length)
        self._assert_live_stream_video(metadata.video, fps)
        self._assert_live_stream_audio(metadata.audio)

    def _assert_live_stream_video(self, video: FfprobeVideoOutput, fps: int):
        self.assert_equal(video.codec, "hevc")
        self.assert_equal(video.width, 1920)
        self.assert_equal(video.height, 1080)
        self.assert_greater(video.real_base_fps, Fraction(f"{fps - 1}/1"))
        self.assert_less(video.real_base_fps, Fraction(f"{fps + 1}/1"))

    def _assert_live_stream_audio(self, audio: FfprobeAudioOutput):
        self.assert_equal(audio.codec, "aac")

    def assert_recording(
        self,
        recording: Path,
        has_qr_codes: bool = True,
        duplicated_frames_crops: List[Crop] | None = None,
        has_audio_time_codes: bool = False,
        width: int = 1920,
        height: int = 1080,
        fps: int = 30,
        video_codec: str = "hevc",
    ):
        metadata = ffprobe(recording)
        self.assert_greater(metadata.format.duration, 8)
        self.assert_less(metadata.format.duration, 14)
        self._assert_video(
            metadata.video,
            recording,
            has_qr_codes,
            duplicated_frames_crops,
            width,
            height,
            fps,
            video_codec,
        )
        self._assert_audio(recording, metadata.audio, has_audio_time_codes)

    def wait_until(self, check: Callable[[], bool]):
        end_time = time.monotonic() + 15
        while time.monotonic() < end_time:
            if check():
                return
            time.sleep(0.1)
        raise Exception("Timeout waiting for condition to be true")

    def _assert_video(
        self,
        video: FfprobeVideoOutput,
        recording: Path,
        has_qr_codes: bool,
        duplicated_frames_crops: List[Crop] | None,
        width,
        height,
        fps: int,
        video_codec: str,
    ):
        self.assert_equal(video.codec, video_codec)
        self.assert_equal(video.width, width)
        self.assert_equal(video.height, height)
        self.assert_greater(video.average_fps, Fraction(f"{fps - 1}/1"))
        self.assert_less(video.average_fps, Fraction(f"{fps + 1}/1"))
        self.assert_presentation_time_stamps(
            recording, 1 / fps, [frame.pts for frame in video.frames]
        )
        self._assert_video_frame_numbers_increasing(recording, has_qr_codes)
        picture_types = {frame.picture_type for frame in video.frames}
        self.assert_equal(len(picture_types), 3)
        self.assert_in("I", picture_types)
        self.assert_in("P", picture_types)
        self.assert_in("B", picture_types)
        if duplicated_frames_crops is None:
            self._assert_no_duplicated_frames(fps, video, recording)
        else:
            for crop in duplicated_frames_crops:
                self._assert_no_duplicated_frames(fps, video, recording, crop)

    def _assert_no_duplicated_frames(
        self,
        fps: int,
        video: FfprobeVideoOutput,
        recording: Path,
        crop: Crop | None = None,
    ):
        filtered_video = ffprobe_video(remove_duplicated_frames(recording, crop))
        self.assert_presentation_time_stamps(
            recording, 1 / fps, [frame.pts for frame in filtered_video.frames]
        )
        self.assert_equal(len(filtered_video.frames), len(video.frames))

    def _assert_audio(
        self, recording: Path, audio: FfprobeAudioOutput, has_audio_time_codes: bool
    ):
        expected_samples_per_frame = 1024
        self.assert_equal(audio.codec, "aac")
        self.assert_equal(audio.profile, "LC")
        self.assert_equal(audio.sample_rate, 48000)
        self.assert_equal(audio.channels, 1)
        self.assert_equal(audio.channel_layout, "mono")
        self.assert_greater(audio.bit_rate, 120_000)
        self.assert_less(audio.bit_rate, 136_000)
        self.assert_presentation_time_stamps(
            recording,
            expected_samples_per_frame / audio.sample_rate,
            [frame.pts for frame in audio.frames],
        )
        self._assert_audio_time_codes(recording, has_audio_time_codes)
        for frame in audio.frames:
            self.assert_equal(frame.channels, 1)
            self.assert_equal(frame.number_of_samples, expected_samples_per_frame)

    def assert_presentation_time_stamps(
        self,
        recording: Path,
        expected_delta: float,
        presentation_time_stamps: List[float],
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
            for missing_presentation_time_stamp in missing_presentation_time_stamps:
                LOGGER.info("Missing PTS: %s", missing_presentation_time_stamp)
        self.assert_equal(len(missing_presentation_time_stamps), 0)

    def _assert_video_frame_numbers_increasing(
        self, recording: Path, has_qr_codes: bool
    ):
        if not has_qr_codes:
            return
        qr_codes = read_qr_codes(recording, Crop(x=150, y=0, width=400, height=400))
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

    def _assert_audio_time_codes(self, recording: Path, has_audio_time_codes: bool):
        if not has_audio_time_codes:
            return
        ltc_wav = Path("files/ltc.wav")
        extract_ltc_wav(recording, ltc_wav)
        output = subprocess.run(
            ["ltcdump", "--fps", "30", ltc_wav],
            check=True,
            capture_output=True,
            text=True,
        ).stdout
        has_seen_start_time = False
        has_seen_end_time = False
        for line in output.splitlines():
            mo = RE_LTCDUMP.match(line)
            if mo:
                seconds = 60 * int(mo.group(1)) + int(mo.group(2))
                if seconds < 3:
                    has_seen_start_time = True
                if seconds > 9:
                    has_seen_end_time = True
            elif "#DISCONTINUITY" in line:
                if has_seen_start_time and not has_seen_end_time:
                    for line in output.splitlines():
                        LOGGER.info("ltcdump: %s", line)
                    raise Exception("Discontinuity in audio!")
        self.assert_true(has_seen_start_time)
        self.assert_true(has_seen_end_time)


def find_missing_presentation_time_stamps(
    expected_delta: float, presentation_time_stamps: List[float], delta_error: float
) -> List[float]:
    missing_presentation_time_stamps = []
    for index in range(1, len(presentation_time_stamps)):
        current = presentation_time_stamps[index]
        previous = presentation_time_stamps[index - 1]
        delta = current - previous
        if delta < expected_delta - delta_error or delta > expected_delta + delta_error:
            missing_presentation_time_stamps.append(current)
    return missing_presentation_time_stamps
