from fractions import Fraction
import logging
from pathlib import Path
import time
from typing import List

import systest

from .utils import Crop
from .ffmpeg import FfprobeAudioOutput
from .ffmpeg import FfprobeVideoOutput
from .ffmpeg import ffprobe
from .ffmpeg import find_duplicated_frames
from .ffmpeg import read_qr_codes

from .moblin import Moblin

LOGGER = logging.getLogger(__name__)


class TestCase(systest.TestCase):
    def __init__(self, moblin: Moblin):
        super().__init__()
        self.moblin = moblin

    def teardown(self):
        self.moblin.end()
        self.moblin.stop_recording()

    def wait_for_ingest_stream_started(self, number_of_ingests=2, startup_delay=1):
        time.sleep(startup_delay)
        self.moblin.wait_for_ingests(
            minimim_bitrate=0,
            maximum_bitrate=100_000_000,
            total_bytes=3_000_000,
            number_of_ingests=number_of_ingests,
        )

    def assert_recording(
        self,
        recording: Path,
        has_qr_codes: bool = True,
        duplicated_frames_crops: List[Crop] | None = None,
    ):
        recording_metadata = ffprobe(recording)
        self.assert_greater(recording_metadata.format.duration, 8)
        self.assert_less(recording_metadata.format.duration, 14)
        self._assert_video(
            recording_metadata.video, recording, has_qr_codes, duplicated_frames_crops
        )
        self._assert_audio(recording_metadata.audio)

    def _assert_video(
        self,
        video: FfprobeVideoOutput,
        recording: Path,
        has_qr_codes: bool,
        duplicated_frames_crops: List[Crop] | None,
    ):
        fps = 30
        self.assert_equal(video.codec, "hevc")
        self.assert_greater(video.fps, Fraction(f"{fps - 1}/1"))
        self.assert_less(video.fps, Fraction(f"{fps + 1}/1"))
        self._assert_presentation_time_stamps(
            1 / fps, [frame.pts for frame in video.frames]
        )
        self._assert_video_frame_numbers_increasing(recording, has_qr_codes)
        picture_types = {frame.picture_type for frame in video.frames}
        self.assert_equal(len(picture_types), 3)
        self.assert_in("I", picture_types)
        self.assert_in("P", picture_types)
        self.assert_in("B", picture_types)
        if duplicated_frames_crops is None:
            self.assert_equal(find_duplicated_frames(recording), 0)
        else:
            for crop in duplicated_frames_crops:
                self.assert_equal(find_duplicated_frames(recording, crop), 0)

    def _assert_audio(self, audio: FfprobeAudioOutput):
        expected_samples_per_frame = 1024
        self.assert_equal(audio.codec, "aac")
        self.assert_equal(audio.profile, "LC")
        self.assert_equal(audio.sample_rate, 48000)
        self.assert_equal(audio.channels, 1)
        self.assert_equal(audio.channel_layout, "mono")
        self.assert_greater(audio.bit_rate, 124_000)
        self.assert_less(audio.bit_rate, 132_000)
        self._assert_presentation_time_stamps(
            expected_samples_per_frame / audio.sample_rate,
            [frame.pts for frame in audio.frames],
        )
        for frame in audio.frames:
            self.assert_equal(frame.channels, 1)
            self.assert_equal(frame.number_of_samples, expected_samples_per_frame)

    def _assert_presentation_time_stamps(
        self, expected_delta: float, presentation_time_stamps: List[float]
    ):
        self.assert_greater(len(presentation_time_stamps), 0)
        for index in range(1, len(presentation_time_stamps)):
            current = presentation_time_stamps[index]
            previous = presentation_time_stamps[index - 1]
            delta = current - previous
            self.assert_greater(delta, expected_delta - 0.001)
            self.assert_less(delta, expected_delta + 0.001)

    def _assert_video_frame_numbers_increasing(
        self, recording: Path, has_qr_codes: bool
    ):
        if not has_qr_codes:
            return
        qr_codes = read_qr_codes(recording)
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
