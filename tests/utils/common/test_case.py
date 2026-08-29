import logging
import re
import statistics
from collections.abc import Callable
from datetime import datetime
from fractions import Fraction
from pathlib import Path

import systest
from systest import wait_until

from .ffmpeg import Crop
from .ffmpeg import FfmpegVideoCodec
from .ffmpeg import FfprobeAudioOutput
from .ffmpeg import FfprobeVideoOutput
from .ffmpeg import Image
from .ffmpeg import QrCode
from .ffmpeg import detect_silence
from .ffmpeg import ffprobe
from .ffmpeg import ffprobe_audio
from .ffmpeg import ffprobe_video_size
from .ffmpeg import measure_mean_volume
from .ffmpeg import read_video_timecodes
from .utils import RecordingProbe
from .utils import anchor_time_of_day
from .utils import find_missing_presentation_time_stamps
from .utils import probe_recording

LOGGER = logging.getLogger(__name__)
RE_LTCDUMP = re.compile(r"\S+\s+00:(\d+):(\d+):.*")
CHANNEL_LAYOUTS = {1: "mono", 2: "stereo"}
AUDIO_SAMPLES_PER_FRAME = 1024


class TestCase(systest.TestCase):
    def assert_live_stream(
        self,
        recording: Path,
        minimum_length: float | None = 7,
        maximum_length: float | None = 20,
        width: int = 1920,
        height: int = 1080,
        fps: int = 30,
    ) -> None:
        metadata = ffprobe(recording)
        if minimum_length is not None:
            self.assert_greater(metadata.format.duration, minimum_length, "Minimum live stream length.")
        if maximum_length is not None:
            self.assert_less(metadata.format.duration, maximum_length, "Maximum live stream length.")
        self._assert_live_stream_video(metadata.video, width, height, fps)
        self._assert_live_stream_audio(metadata.audio)

    def _assert_live_stream_video(self, video: FfprobeVideoOutput, width: int, height: int, fps: int) -> None:
        self.assert_equal(video.codec, FfmpegVideoCodec.HEVC)
        self.assert_equal(video.width, width)
        self.assert_equal(video.height, height)
        self.assert_fps(video.real_base_fps, fps)

    def _assert_live_stream_audio(self, audio: FfprobeAudioOutput) -> None:
        self.assert_equal(audio.codec, "aac")

    def assert_recording(
        self,
        recording: Path,
        files_dir: Path,
        has_qr_codes: bool = True,
        duplicated_frames_crops: list[Crop] | None = None,
        has_audio_time_codes: bool = False,
        width: int = 1920,
        height: int = 1080,
        fps: int = 30,
        video_codec: FfmpegVideoCodec = FfmpegVideoCodec.HEVC,
        channels: int = 1,
    ) -> None:
        probe = probe_recording(
            recording, has_qr_codes, duplicated_frames_crops, has_audio_time_codes, files_dir
        )
        self.assert_greater(probe.format.duration, 8, "Minimum recording length.")
        self.assert_less(probe.format.duration, 14, "Maximum recording length.")
        self._assert_video(probe, recording, width, height, fps, video_codec)
        self._assert_audio(probe, recording, channels)

    def assert_timecodes(self, recording: Path, start: datetime, end: datetime, fps: int = 30) -> None:
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

    def assert_no_audio_glitches(self, recording: Path) -> None:
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

    def assert_fps(self, actual: Fraction | None, fps: int) -> None:
        if actual is None:
            raise Exception(f"No frame rate reported by ffprobe. Expected {fps}.")
        self.assert_greater(actual, Fraction(f"{fps - 1}/1"))
        self.assert_less(actual, Fraction(f"{fps + 1}/1"))

    def assert_video_size(self, recording: Path, width: int, height: int) -> None:
        self.assert_equal(ffprobe_video_size(recording), (width, height))

    def assert_all_black(self, image: Image) -> None:
        if image.is_all_black():
            return
        position = image.find_non_black_pixel() or (-1, -1)
        raise Exception(f"Pixel at {position} is {image.pixel(*position)}, but expected it to be black.")

    def assert_not_all_black(self, image: Image, minimum_ratio: float = 0.01) -> None:
        self.assert_greater(image.non_black_ratio(), minimum_ratio)

    def wait_until(self, check: Callable[[], bool]) -> None:
        wait_until(check, "condition to be true")

    def _assert_video(
        self,
        probe: RecordingProbe,
        recording: Path,
        width: int,
        height: int,
        fps: int,
        video_codec: FfmpegVideoCodec,
    ) -> None:
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
    ) -> None:
        self.assert_presentation_time_stamps(recording, 1 / fps, presentation_time_stamps, "video")
        self.assert_equal(len(presentation_time_stamps), len(video.frames))

    def _assert_audio(self, probe: RecordingProbe, recording: Path, channels: int) -> None:
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

    def _assert_audio_presentation_time_stamps(self, recording: Path, audio: FfprobeAudioOutput) -> None:
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
    ) -> None:
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

    def _assert_video_frame_numbers_increasing(self, qr_codes: list[QrCode] | None) -> None:
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

    def _assert_audio_time_codes(self, output: str | None) -> None:
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

    def _log_output(self, output: str) -> None:
        for line in output.splitlines():
            LOGGER.info("ltcdump: %s", line)
