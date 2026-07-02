from dataclasses import dataclass
import json
import logging
from pathlib import Path
import shutil
import subprocess
from fractions import Fraction
from typing import List
from .utils import log_output

LOGGER = logging.getLogger(__name__)


class FfmpegCommand:
    def __init__(self):
        self._server = None

    def args(self) -> List[str]:
        raise NotImplementedError

    def __enter__(self):
        command = ["ffmpeg", "-hide_banner", "-nostdin", "-y"] + self.args()
        LOGGER.debug("Command: %s", " ".join(command))
        self._server = subprocess.Popen(
            command,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        log_output(self._server.stdout, LOGGER)
        log_output(self._server.stderr, LOGGER)
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

    def args(self):
        return [
            "-re",
            "-f",
            "lavfi",
            "-i",
            "testsrc2=size=1920x1080:rate=30",
            "-f",
            "lavfi",
            "-i",
            "aevalsrc=exprs='if(lt(mod(t,1),0.015),0.8*sin(2*PI*1800*t)*exp(-80*mod(t,1)),0)':s=48000",
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
    codec: str
    profile: str
    sample_rate: int
    channels: int
    channel_layout: str
    bit_rate: int
    frames: List[FfprobeAudioOutputFrame]


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
    LOGGER.debug("Command: %s", " ".join(command))
    output = subprocess.run(
        command,
        check=True,
        capture_output=True,
        text=True,
    ).stdout
    return json.loads(output)


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


def ffprobe_audio(path):
    output = ffprobe_run(
        path,
        "-select_streams",
        "a:0",
        "-show_entries",
        "stream=codec_name,profile,sample_rate,channels,channel_layout,bit_rate:frame=nb_samples,pts_time,channels",
    )
    stream = output["streams"][0]
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
    metadata = FfprobeOutput(
        video=ffprobe_video(path),
        audio=ffprobe_audio(path),
        format=ffprobe_format(path),
    )
    LOGGER.debug("File: %s, Metadata: %s", path, metadata)
    return metadata


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
            LOGGER.info("Failed QR decode of %s. Output: '%s'", proc.args[-1], text)
            self.number = -1
            self.pts = -1


def read_qr_codes(path: Path):
    qr_codes_dir = Path(f"{path}-qr-codes")
    qr_codes_dir.mkdir()
    subprocess.run(
        [
            "ffmpeg",
            "-i",
            path,
            "-vf",
            "crop=w=400:h=400:x=150:y=0",
            f"{qr_codes_dir}/%05d.jpg",
        ],
        check=True,
        capture_output=True,
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
