import functools
import json
import logging
import math
import re
import shutil
import subprocess
from dataclasses import dataclass
from dataclasses import field
from enum import StrEnum
from fractions import Fraction
from pathlib import Path

from .process import ManagedProcess
from .utils import FILES_DIR
from .utils import Crop
from .utils import Image

LOGGER = logging.getLogger(__name__)
FFMPEG_COMMAND = ["ffmpeg", "-hide_banner", "-nostdin", "-y"]
CAPTURE_EXTRA_TIMEOUT = 30
RE_VOLUME_DETECT = re.compile(r"(n_samples|mean_volume|max_volume): (-?[\d.]+|-?inf)")
RE_PROGRESS_FRAME = re.compile(r"^frame=(\d+)$", re.MULTILINE)


class FfmpegVideoCodec(StrEnum):
    H264 = "h264"
    HEVC = "hevc"


class TransportFormat(StrEnum):
    FLV = "flv"
    MPEGTS = "mpegts"
    RTSP = "rtsp"
    WHIP = "whip"


HARDWARE_VIDEO_ENCODERS = {
    FfmpegVideoCodec.H264: "h264_videotoolbox",
    FfmpegVideoCodec.HEVC: "hevc_videotoolbox",
}
SOFTWARE_VIDEO_ENCODERS = {
    FfmpegVideoCodec.H264: "libx264",
    FfmpegVideoCodec.HEVC: "libx265",
}


def _log_level(line: str) -> int:
    if line.startswith("Error") or "No such filter" in line:
        return logging.ERROR
    else:
        return logging.DEBUG


def _run(command: list[str], timeout: float | None = None):
    LOGGER.debug("Command: %s", " ".join(command))
    return subprocess.run(
        command, check=True, capture_output=True, text=True, timeout=timeout
    )


def _run_binary(command: list[str]) -> bytes:
    LOGGER.debug("Command: %s", " ".join(command))
    return subprocess.run(command, check=True, capture_output=True).stdout


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


@functools.cache
def video_encoder(codec: FfmpegVideoCodec) -> str:
    hardware_encoder = HARDWARE_VIDEO_ENCODERS[codec]
    if f" {hardware_encoder} " in ffmpeg_run("-encoders").stdout:
        return hardware_encoder
    LOGGER.warning(
        "The hardware video encoder %s is not supported by ffmpeg. Encoding %s in software.",
        hardware_encoder,
        codec,
    )
    return SOFTWARE_VIDEO_ENCODERS[codec]


def video_encoder_args(
    bitrate: int, codec: FfmpegVideoCodec, realtime: bool
) -> list[str]:
    encoder = video_encoder(codec)
    args = ["-c:v", encoder, "-b:v", str(bitrate)]
    if encoder in HARDWARE_VIDEO_ENCODERS.values():
        if realtime:
            args += ["-realtime", "1"]
    else:
        args += [
            "-maxrate",
            str(bitrate),
            "-bufsize",
            str(2 * bitrate),
            "-preset",
            "veryfast",
        ]
    return args


def check_dependencies() -> list[str]:
    output = ffmpeg_run("-filters").stdout
    missing_dependencies = []
    for video_filter in ["qrencode", "drawtext"]:
        if f" {video_filter} " not in output:
            missing_dependencies.append(
                f"The {video_filter} video filter is not supported by ffmpeg"
            )
    return missing_dependencies


def _ensure_certificate_exists(certificate_file: Path, key_file: Path):
    if certificate_file.exists() and key_file.exists():
        return
    _run(
        [
            "openssl",
            "ecparam",
            "-name",
            "prime256v1",
            "-genkey",
            "-noout",
            "-out",
            str(key_file),
        ]
    )
    _run(
        [
            "openssl",
            "req",
            "-x509",
            "-new",
            "-key",
            str(key_file),
            "-out",
            str(certificate_file),
            "-days",
            "3650",
            "-subj",
            "/CN=Moblin test",
        ]
    )


class FfmpegCommand:
    def __init__(self, quiet: bool = False):
        self._process: ManagedProcess | None = None
        self._quiet = quiet

    def args(self) -> list[str]:
        raise NotImplementedError

    def __enter__(self):
        self._start()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self._stop()

    def is_running(self) -> bool:
        return self._process is not None and self._process.is_running()

    def restart(self):
        self._stop()
        self._start()

    def _start(self):
        command = list(FFMPEG_COMMAND)
        if self._quiet:
            command += ["-nostats", "-loglevel", "warning"]
        command += self.args()
        self._process = ManagedProcess(
            command, LOGGER, stdin=subprocess.DEVNULL, log_level=_log_level
        )
        self._process.start()

    def _stop(self):
        if self._process is not None:
            self._process.stop()
            self._process = None


class FfmpegTestStream(FfmpegCommand):
    def __init__(
        self,
        url,
        transport_format=TransportFormat.FLV,
        video_codec=FfmpegVideoCodec.H264,
        video_profile=None,
        video_bitrate=8_000_000,
        audio_codec="aac",
        audio_channels=1,
        muxer_args=None,
        loop_audio=False,
        quiet=False,
    ):
        super().__init__(quiet)
        self._url = url
        self._transport_format = transport_format
        self._video_codec = video_codec
        self._video_profile = video_profile
        self._video_bitrate = video_bitrate
        self._audio_codec = audio_codec
        self._audio_channels = audio_channels
        self._muxer_args = muxer_args or []
        self._loop_audio = loop_audio
        self._audio_file = FILES_DIR / "FfmpegTestStream.wav"
        self._ensure_audio_file_exists()

    def _ensure_audio_file_exists(self):
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
        video_profile = []
        if self._video_profile is not None:
            video_profile = ["-profile:v", self._video_profile]
        audio_input = []
        if self._loop_audio:
            audio_input = ["-re", "-stream_loop", "-1"]
        return [
            "-re",
            "-f",
            "lavfi",
            "-i",
            "testsrc2=size=1920x1080:rate=30",
            *audio_input,
            "-i",
            str(self._audio_file),
            *video_encoder_args(self._video_bitrate, self._video_codec, True),
            *video_profile,
            "-pix_fmt",
            "yuv420p",
            "-g",
            "60",
            "-keyint_min",
            "60",
            "-c:a",
            self._audio_codec,
            "-b:a",
            "128k",
            "-ar",
            "48000",
            "-ac",
            str(self._audio_channels),
            "-vf",
            "qrencode=text=n %{frame_num} pts %{pts}:q=400:x=150,"
            "drawtext=fontsize=60:text=%{frame_num}:x=10:y=100",
            "-f",
            self._transport_format,
            *self._muxer_args,
            self._url,
        ]


class FfmpegWhipTestStream(FfmpegTestStream):
    def __init__(self, url, **kwargs):
        certificate_file = FILES_DIR / "FfmpegWhipTestStream.crt"
        key_file = FILES_DIR / "FfmpegWhipTestStream.key"
        _ensure_certificate_exists(certificate_file, key_file)
        super().__init__(
            url=url,
            transport_format=TransportFormat.WHIP,
            video_profile="baseline",
            audio_codec="libopus",
            audio_channels=2,
            muxer_args=[
                "-cert_file",
                str(certificate_file),
                "-key_file",
                str(key_file),
            ],
            **kwargs,
        )


class FfmpegRtspTestStream(FfmpegTestStream):
    def __init__(self, url, **kwargs):
        super().__init__(
            url=url,
            transport_format=TransportFormat.RTSP,
            video_profile="baseline",
            audio_codec="libopus",
            audio_channels=2,
            muxer_args=["-rtsp_transport", "tcp"],
            **kwargs,
        )


class FfmpegAudioTestStream(FfmpegCommand):
    def __init__(self, url, transport_format=TransportFormat.FLV):
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
    width: int
    height: int
    real_base_fps: Fraction | None
    average_fps: Fraction | None
    frames: list[FfprobeVideoOutputFrame]


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
    frames: list[FfprobeAudioOutputFrame] = field(default_factory=list)


@dataclass
class FfprobeFormatOutput:
    duration: float


@dataclass
class FfprobeOutput:
    video: FfprobeVideoOutput
    audio: FfprobeAudioOutput
    format: FfprobeFormatOutput


def ffprobe_video(path: Path):
    output = ffprobe_run(
        path,
        "-select_streams",
        "v:0",
        "-show_entries",
        "stream=codec_name,width,height,r_frame_rate,avg_frame_rate:frame=pict_type,pts_time",
    )
    stream = output["streams"][0]
    real_base_fps = _get_fps(stream, "r_frame_rate")
    average_fps = _get_fps(stream, "avg_frame_rate")
    frames = [FfprobeVideoOutputFrame(frame) for frame in output["frames"]]
    return FfprobeVideoOutput(
        codec=stream["codec_name"],
        width=stream["width"],
        height=stream["height"],
        real_base_fps=real_base_fps,
        average_fps=average_fps,
        frames=frames,
    )


def ffprobe_video_size(path: Path) -> tuple[int, int]:
    output = ffprobe_run(
        path, "-select_streams", "v:0", "-show_entries", "stream=width,height"
    )
    stream = output["streams"][0]
    return stream["width"], stream["height"]


def _get_fps(stream, name: str) -> Fraction | None:
    try:
        return Fraction(stream[name])
    except Exception:
        return None


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
class StreamContent:
    duration: float = 0
    video_codec: str = ""
    width: int = 0
    height: int = 0
    video_duration: float = 0
    video_frames: int = 0
    unique_video_frames: int = 0
    audio_codec: str = ""
    sample_rate: int = 0
    channels: int = 0
    audio_duration: float = 0
    mean_volume_db: float = -math.inf
    max_volume_db: float = -math.inf

    def has_video(self) -> bool:
        return self.video_codec != ""

    def has_audio(self) -> bool:
        return self.audio_codec != ""

    def video_fps(self) -> float:
        if self.video_duration <= 0:
            return 0
        return self.video_frames / self.video_duration

    def unique_video_frames_ratio(self) -> float:
        if self.video_frames == 0:
            return 0
        return self.unique_video_frames / self.video_frames


def capture_stream_content(url: str, duration: float, path: Path) -> StreamContent:
    _record_stream(url, duration, path)
    return probe_stream_content(path)


def _record_stream(url: str, duration: float, path: Path):
    path.unlink(missing_ok=True)
    _run(
        FFMPEG_COMMAND
        + [
            "-nostats",
            "-loglevel",
            "warning",
            "-i",
            url,
            "-t",
            str(duration),
            "-c",
            "copy",
            "-f",
            "mpegts",
            str(path),
        ],
        timeout=duration + CAPTURE_EXTRA_TIMEOUT,
    )


def probe_stream_content(path: Path) -> StreamContent:
    content = StreamContent()
    output = ffprobe_run(
        path,
        "-count_packets",
        "-show_entries",
        "format=duration:stream=codec_type,codec_name,width,height,duration,"
        "sample_rate,channels,nb_read_packets",
    )
    content.duration = _to_float(output["format"].get("duration"))
    for stream in output["streams"]:
        codec_type = stream.get("codec_type")
        if codec_type == "video" and not content.has_video():
            content.video_codec = stream["codec_name"]
            content.width = stream["width"]
            content.height = stream["height"]
            content.video_duration = _to_float(stream.get("duration"))
            content.video_frames = int(stream["nb_read_packets"])
        elif codec_type == "audio" and not content.has_audio():
            content.audio_codec = stream["codec_name"]
            content.sample_rate = int(stream["sample_rate"])
            content.channels = stream["channels"]
    _measure_stream_content(path, content)
    return content


def _measure_stream_content(path: Path, content: StreamContent):
    args = ["-nostats", "-progress", "pipe:1", "-i", str(path)]
    if content.has_video():
        args += ["-vf", "mpdecimate", "-fps_mode", "vfr"]
    if content.has_audio():
        args += ["-af", "volumedetect"]
    args += ["-f", "null", "-"]
    proc = _run(FFMPEG_COMMAND + args, timeout=CAPTURE_EXTRA_TIMEOUT)
    if content.has_video():
        content.unique_video_frames = _parse_progress_frames(proc.stdout)
    if content.has_audio():
        _parse_volume_detect(proc.stderr, content)


def _parse_progress_frames(output: str) -> int:
    matches = RE_PROGRESS_FRAME.findall(output)
    if len(matches) == 0:
        return 0
    return int(matches[-1])


def _parse_volume_detect(output: str, content: StreamContent):
    number_of_samples = 0
    for name, value in RE_VOLUME_DETECT.findall(output):
        if name == "n_samples":
            number_of_samples = max(number_of_samples, int(value))
        elif name == "mean_volume":
            content.mean_volume_db = float(value)
        else:
            content.max_volume_db = float(value)
    samples_per_second = content.sample_rate * content.channels
    if samples_per_second > 0:
        content.audio_duration = number_of_samples / samples_per_second


def _to_float(value) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return 0


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


def read_qr_codes(path: Path, crop: Crop) -> list[QrCode]:
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


def read_video_frame(path: Path, timestamp: float, crop: Crop | None = None) -> Image:
    args = ["-ss", str(timestamp), "-i", str(path), "-frames:v", "1"]
    if crop is None:
        width, height = ffprobe_video_size(path)
    else:
        width, height = crop.width, crop.height
        args += ["-vf", f"crop=x={crop.x}:y={crop.y}:w={crop.width}:h={crop.height}"]
    args += ["-f", "rawvideo", "-pix_fmt", "rgb24", "-"]
    data = _run_binary(FFMPEG_COMMAND + args)
    return Image(width, height, data)


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
    filtered_path = path.with_suffix(f".{'-'.join(filters)}-filtered.mp4")
    args += [
        ", ".join(filters),
        *video_encoder_args(8_000_000, FfmpegVideoCodec.H264, False),
        "-an",
        str(filtered_path),
    ]
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
        *video_encoder_args(1_000_000, FfmpegVideoCodec.H264, False),
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
