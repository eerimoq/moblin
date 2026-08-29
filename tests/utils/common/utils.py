import subprocess
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from pathlib import Path

from .ffmpeg import Crop
from .ffmpeg import FfprobeAudioOutput
from .ffmpeg import FfprobeFormatOutput
from .ffmpeg import FfprobeVideoOutput
from .ffmpeg import QrCode
from .ffmpeg import extract_ltc_wav
from .ffmpeg import ffprobe_audio
from .ffmpeg import ffprobe_format
from .ffmpeg import ffprobe_video
from .ffmpeg import read_qr_codes
from .ffmpeg import read_unique_frame_presentation_time_stamps


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
    files_dir: Path,
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
        audio_time_codes_future = executor.submit(
            _read_audio_time_codes, recording, has_audio_time_codes, files_dir
        )
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


def _read_audio_time_codes(recording: Path, has_audio_time_codes: bool, files_dir: Path) -> str | None:
    if not has_audio_time_codes:
        return None
    ltc_wav = files_dir / "ltc.wav"
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
