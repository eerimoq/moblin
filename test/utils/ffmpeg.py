import json
import logging
import shutil
import subprocess
from dataclasses import dataclass
from dataclasses import field
from fractions import Fraction
from pathlib import Path
from typing import List

from .utils import Crop
from .utils import log_output

LOGGER = logging.getLogger(__name__)


def _log_level(line: str) -> int:
    if line.startswith("Error") or "No such filter" in line:
        return logging.ERROR
    else:
        return logging.DEBUG


def _run(command: List[str]):
    LOGGER.debug("Command: %s", " ".join(command))
    return subprocess.run(command, check=True, capture_output=True, text=True)


def check_dependencies() -> List[str]:
    output = ffmpeg_run("-filters").stdout
    missing_dependencies = []
    for video_filter in ["qrencode", "drawtext"]:
        if f" {video_filter} " not in output:
            missing_dependencies.append(
                f"The {video_filter} video filter is not supported by ffmpeg"
            )
    return missing_dependencies


FFMPEG_COMMAND = ["ffmpeg", "-hide_banner", "-nostdin", "-y"]


class FfmpegCommand:
    def __init__(self):
        self._server = None

    def args(self) -> List[str]:
        raise NotImplementedError

    def __enter__(self):
        command = FFMPEG_COMMAND + self.args()
        LOGGER.debug("Command: %s", " ".join(command))
        self._server = subprocess.Popen(
            command,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        log_output(self._server.stdout, LOGGER, _log_level)
        log_output(self._server.stderr, LOGGER, _log_level)
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        if self._server is not None:
            self._server.kill()
            self._server.wait()


class FfmpegTestStream(FfmpegCommand):
    def __init__(self, url, transport_format="flv", video_codec="libx264"):
        super().__init__()
        self._url = url
        self._transport_format = transport_format
        self._video_codec = video_codec
        self._audio_file = Path("FfmpegTestStream.wav")
        self.enusure_audio_file_exists()

    def enusure_audio_file_exists(self):
        if not self._audio_file.exists():
            _run(
                [
                    "ltcgen",
                    "--fps",
                    "30",
                    "--timecode",
                    "00:00:00:00",
                    "--duration",
                    "00:05:00:00",
                    str(self._audio_file),
                ]
            )

    def args(self):
        return [
            "-re",
            "-f",
            "lavfi",
            "-i",
            "testsrc2=size=1920x1080:rate=30",
            "-i",
            str(self._audio_file),
            "-c:v",
            self._video_codec,
            "-b:v",
            "8M",
            "-maxrate",
            "8M",
            "-bufsize",
            "16M",
            "-preset",
            "veryfast",
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
            "-vf",
            "qrencode=text=n %{frame_num} pts %{pts}:q=400:x=150,"
            "drawtext=fontsize=60:text=%{frame_num}:x=10:y=100",
            "-f",
            self._transport_format,
            self._url,
        ]


class FfmpegAudioTestStream(FfmpegCommand):
    def __init__(self, url, transport_format="flv"):
        super().__init__()
        self._url = url
        self._transport_format = transport_format

    def args(self):
        return [
            "-re",
            "-f",
            "lavfi",
            "-i",
            "aevalsrc=exprs='if(lt(mod(t,1),0.015),0.8*sin(2*PI*1800*t)*exp(-80*mod(t,1)),0)':s=48000",
            "-c:a",
            "aac",
            "-b:a",
            "128k",
            "-f",
            self._transport_format,
            self._url,
        ]


class FfmpegServer(FfmpegCommand):
    def __init__(self, url: str, filename: Path):
        super().__init__()
        self._url = url
        self._filename = filename

    def args(self):
        return [
            "-i",
            self._url,
            "-c",
            "copy",
            str(self._filename),
        ]


@dataclass
class FfprobeVideoOutputFrame:
    pts: float
    picture_type: str

    def __init__(self, frame):
        self.pts = float(frame["pts_time"])
        self.picture_type = frame["pict_type"]


@dataclass
class FfprobeVideoOutput:
    codec: str
    fps: Fraction | None
    frames: List[FfprobeVideoOutputFrame]


@dataclass
class FfprobeAudioOutputFrame:
    pts: float
    channels: int
    number_of_samples: int

    def __init__(self, frame):
        self.pts = float(frame["pts_time"])
        self.channels = frame["channels"]
        self.number_of_samples = frame["nb_samples"]


@dataclass
class FfprobeAudioOutput:
    codec: str = ""
    profile: str = ""
    sample_rate: int = 0
    channels: int = 0
    channel_layout: str = ""
    bit_rate: int = 0
    frames: List[FfprobeAudioOutputFrame] = field(default_factory=list)


@dataclass
class FfprobeFormatOutput:
    duration: float


@dataclass
class FfprobeOutput:
    video: FfprobeVideoOutput
    audio: FfprobeAudioOutput
    format: FfprobeFormatOutput


def ffprobe_run(path: Path, *args):
    command = [
        "ffprobe",
        "-output_format",
        "json",
        *args,
        str(path),
    ]
    output = _run(command).stdout
    return json.loads(output)


def ffmpeg_run(*args):
    return _run(FFMPEG_COMMAND + [*args])


def ffprobe_video(path: Path):
    output = ffprobe_run(
        path,
        "-select_streams",
        "v:0",
        "-show_entries",
        "stream=codec_name,r_frame_rate,avg_frame_rate:frame=pict_type,pts_time",
    )
    stream = output["streams"][0]
    try:
        fps = Fraction(stream["avg_frame_rate"])
    except Exception:
        fps = None
    frames = [FfprobeVideoOutputFrame(frame) for frame in output["frames"]]
    return FfprobeVideoOutput(codec=stream["codec_name"], fps=fps, frames=frames)


def ffprobe_audio(path) -> FfprobeAudioOutput:
    output = ffprobe_run(
        path,
        "-select_streams",
        "a:0",
        "-show_entries",
        "stream=codec_name,profile,sample_rate,channels,channel_layout,bit_rate:frame=nb_samples,pts_time,channels",
    )
    streams = output["streams"]
    if len(streams) == 0:
        return FfprobeAudioOutput()
    stream = streams[0]
    frames = [FfprobeAudioOutputFrame(frame) for frame in output["frames"]]
    return FfprobeAudioOutput(
        codec=stream["codec_name"],
        profile=stream["profile"],
        sample_rate=int(stream["sample_rate"]),
        channels=stream["channels"],
        channel_layout=stream["channel_layout"],
        bit_rate=int(stream["bit_rate"]),
        frames=frames,
    )


def ffprobe_format(path):
    output = ffprobe_run(path, "-show_entries", "format=duration")
    return FfprobeFormatOutput(duration=float(output["format"]["duration"]))


def ffprobe(path: Path):
    return FfprobeOutput(
        video=ffprobe_video(path),
        audio=ffprobe_audio(path),
        format=ffprobe_format(path),
    )


@dataclass
class QrCode:
    number: int
    pts: float

    def __init__(self, proc):
        text = proc.stdout.read()
        parts = text.split(" ")
        if len(parts) == 4:
            self.number = int(parts[1])
            self.pts = float(parts[3])
        else:
            self.number = -1
            self.pts = -1


def read_qr_codes(path: Path, crop: Crop | None = None) -> List[QrCode]:
    if crop is None:
        crop = Crop(x=150, y=0, width=400, height=400)
    qr_codes_dir = Path(f"{path}-qr-codes")
    qr_codes_dir.mkdir()
    ffmpeg_run(
        "-i",
        str(path),
        "-vf",
        f"crop=x={crop.x}:y={crop.y}:w={crop.width}:h={crop.height}",
        f"{qr_codes_dir}/%05d.jpg",
    )
    procs = []
    for file in sorted(qr_codes_dir.iterdir()):
        proc = subprocess.Popen(
            ["qrtool", "decode", file], stdout=subprocess.PIPE, text=True
        )
        procs.append(proc)
    qr_codes = []
    for proc in procs:
        proc.wait()
        qr_codes.append(QrCode(proc))
    shutil.rmtree(qr_codes_dir)
    return qr_codes


def extract_ltc_wav(path: Path, output: Path):
    ffmpeg_run(
        "-i", str(path), "-vn", "-map", "0:a:0", "-c:a", "pcm_s16le", str(output)
    )


def remove_duplicated_frames(path: Path, crop: Crop | None = None) -> Path:
    args = ["-i", str(path), "-vf"]
    filters = []
    if crop is not None:
        filters.append(f"crop=x={crop.x}:y={crop.y}:w={crop.width}:h={crop.height}")
    filters.append("mpdecimate")
    filtered_path = path.with_suffix(f".{"-".join(filters)}-filtered.mp4")
    args += [", ".join(filters), "-an", str(filtered_path)]
    ffmpeg_run(*args)
    return filtered_path


def create_qr_codes_video(output_file: Path):
    ffmpeg_run(
        "-t",
        "10",
        "-f",
        "lavfi",
        "-i",
        "nullsrc=size=400x400:rate=30",
        "-c:v",
        "libx264",
        "-b:v",
        "1M",
        "-maxrate",
        "1M",
        "-preset",
        "veryfast",
        "-pix_fmt",
        "yuv420p",
        "-g",
        "60",
        "-keyint_min",
        "60",
        "-vf",
        "qrencode=text=n %{frame_num} pts %{pts}:q=400:x=0",
        str(output_file),
    )
