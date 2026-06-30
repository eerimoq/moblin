from dataclasses import dataclass
import json
import logging
import subprocess
from fractions import Fraction
from .utils import log_output

LOGGER = logging.getLogger(__name__)


class FfmpegBase:
    def __init__(self):
        self._server = None

    def args(self):
        return []

    def __enter__(self):
        command = ["ffmpeg", "-nostdin", "-y"] + self.args()
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


class FfmpegTestStream(FfmpegBase):
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
            "qrencode=text=n %{frame_num} pts %{pts}:q=400:x=150",
            "-f",
            self._transport_format,
            self._url,
        ]


class FfmpegAudioTestStream(FfmpegBase):
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


class FfmpegServer(FfmpegBase):
    def __init__(self, url, filename):
        super().__init__()
        self._url = url
        self._filename = filename

    def args(self):
        return [
            "-i",
            self._url,
            "-c",
            "copy",
            self._filename,
        ]


@dataclass
class FfprobeVideoOutput:
    codec: str
    fps: Fraction | None


@dataclass
class FfprobeAudioOutput:
    codec: str


@dataclass
class FfprobeFormatOutput:
    duration: float


@dataclass
class FfprobeOutput:
    video: FfprobeVideoOutput
    audio: FfprobeAudioOutput
    format: FfprobeFormatOutput


def ffprobe_run(path, *args):
    output = subprocess.run(
        [
            "ffprobe",
            "-output_format",
            "json",
            *args,
            path,
        ],
        check=True,
        capture_output=True,
        text=True,
    ).stdout
    return json.loads(output)


def ffprobe_video(path):
    output = ffprobe_run(
        path,
        "-select_streams",
        "v:0",
        "-show_entries",
        "stream=codec_name,r_frame_rate,avg_frame_rate",
    )
    stream = output["streams"][0]
    try:
        fps = Fraction(stream["avg_frame_rate"])
    except Exception:
        fps = None
    return FfprobeVideoOutput(
        codec=stream["codec_name"],
        fps=fps,
    )


def ffprobe_audio(path):
    output = ffprobe_run(
        path,
        "-select_streams",
        "a:0",
        "-show_entries",
        "stream=codec_name,profile,sample_rate,channels,channel_layout,bit_rate",
    )
    stream = output["streams"][0]
    return FfprobeAudioOutput(codec=stream["codec_name"])


def ffprobe_format(path):
    output = ffprobe_run(path, "-show_entries", "format=duration")
    return FfprobeFormatOutput(duration=float(output["format"]["duration"]))


def ffprobe(path):
    return FfprobeOutput(
        video=ffprobe_video(path),
        audio=ffprobe_audio(path),
        format=ffprobe_format(path),
    )
