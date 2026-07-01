from fractions import Fraction
import logging
from pathlib import Path

from utils.recorder import Recorder
from utils.moblin import Moblin
from utils.ffmpeg import read_qr_codes
from utils.ffmpeg import FfmpegTestStream
from utils.ffmpeg import ffprobe
from utils.mediamtx import MediaMtx
from utils.test_case import TestCase

LOGGER = logging.getLogger(__name__)


class RecordTest(TestCase):
    def wait_for_ingest_stream_started(self, number_of_ingests=2):
        self.moblin.wait_for_ingests(
            minimim_bitrate=0,
            maximum_bitrate=100_000_000,
            total_bytes=3_000_000,
            number_of_ingests=number_of_ingests,
        )

    def assert_recording(self, recording: Path):
        recording_metadata = ffprobe(recording)
        self.assert_equal(recording_metadata.video.codec, "hevc")
        self.assert_greater(recording_metadata.video.fps, Fraction("29/1"))
        self.assert_less(recording_metadata.video.fps, Fraction("31/1"))
        self.assert_equal(recording_metadata.audio.codec, "aac")
        self.assert_greater(recording_metadata.format.duration, 8)
        self.assert_less(recording_metadata.format.duration, 12)
        self._assert_frame_numbers_increasing(recording)

    def _assert_frame_numbers_increasing(self, recording: Path):
        qr_codes = read_qr_codes(recording)
        self.assert_greater(len(qr_codes), 0)
        seen_increase = False
        for frame_index in range(1, len(qr_codes)):
            current_frame_number = qr_codes[frame_index].number
            previous_frame_number = qr_codes[frame_index - 1].number
            if current_frame_number == previous_frame_number:
                if seen_increase:
                    raise Exception(f"Frame number {current_frame_number} already seen.")
            elif current_frame_number == previous_frame_number + 1:
                seen_increase = True
            else:
                raise Exception(f"Frame number {current_frame_number} is not one higher than {previous_frame_number}.")


class IngestRtmpServer(RecordTest):
    """Stream to an RTMP server ingest."""

    def run(self):
        self.moblin.set_scene("RTMP")
        stream = FfmpegTestStream(url=f"rtmp://{self.moblin.ip_address}:11935/live/1")
        recorder = Recorder(self.moblin)
        with stream:
            self.wait_for_ingest_stream_started()
            with recorder:
                self.moblin.wait_for_ingests(
                    minimim_bitrate=7_000_000,
                    maximum_bitrate=9_000_000,
                    total_bytes=10_000_000,
                    number_of_ingests=2,
                )
        self.assert_recording(recorder.recording)


class IngestSrtServer(RecordTest):
    """Stream to an SRT server ingest."""

    def run(self):
        self.moblin.set_scene("SRT")
        stream = FfmpegTestStream(
            url=f"srt://{self.moblin.ip_address}:4000?streamid=1",
            transport_format="mpegts",
        )
        recorder = Recorder(self.moblin)
        with stream:
            self.wait_for_ingest_stream_started()
            with recorder:
                self.moblin.wait_for_ingests(
                    minimim_bitrate=7_000_000,
                    maximum_bitrate=9_000_000,
                    total_bytes=10_000_000,
                    number_of_ingests=2,
                )
        self.assert_recording(recorder.recording)


class IngestRtspClientH264(RecordTest):
    """Stream to an RTSP client ingest."""

    def run(self):
        self.moblin.set_scene("RTSP")
        recorder = Recorder(self.moblin)
        with MediaMtx():
            with FfmpegTestStream(url="rtmp://localhost:1935/1"):
                self.wait_for_ingest_stream_started(number_of_ingests=1)
                with recorder:
                    self.moblin.wait_for_ingests(
                        minimim_bitrate=7_000_000,
                        maximum_bitrate=9_000_000,
                        total_bytes=10_000_000,
                        number_of_ingests=1,
                    )
        self.assert_recording(recorder.recording)


class IngestRistServer(RecordTest):
    """Stream to an RIST server ingest."""

    def run(self):
        self.moblin.set_scene("RIST")
        stream = FfmpegTestStream(
            url=f"rist://{self.moblin.ip_address}:6500?virt-dst-port=1",
            transport_format="mpegts",
        )
        recorder = Recorder(self.moblin)
        with stream:
            self.wait_for_ingest_stream_started()
            with recorder:
                self.moblin.wait_for_ingests(
                    minimim_bitrate=7_000_000,
                    maximum_bitrate=9_000_000,
                    total_bytes=10_000_000,
                    number_of_ingests=2,
                )
        self.assert_recording(recorder.recording)


def tests(moblin: Moblin):
    return [
        IngestRtmpServer(moblin),
        IngestSrtServer(moblin),
        IngestRtspClientH264(moblin),
        IngestRistServer(moblin),
    ]
