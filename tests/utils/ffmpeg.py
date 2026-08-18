import functools
import json
import logging
import math
import re
import shutil
import subprocess
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from dataclasses import field
from enum import StrEnum
from fractions import Fraction
from pathlib import Path
from urllib.parse import urlsplit

from .process import ManagedProcess
from .utils import FILES_DIR
from .utils import Crop
from .utils import Image
from .utils import Pixel
from .utils import wait_until

LOGGER = logging.getLogger(__name__)
FFMPEG_COMMAND = ["ffmpeg", "-hide_banner", "-nostdin", "-y"]
RE_VOLUME_DETECT = re.compile(r"(n_samples|mean_volume|max_volume): (-?[\d.]+|-?inf)")
RE_SILENCE_DETECT = re.compile(r"silence_(start|end): (-?[\d.]+)")
RE_SHOWINFO_PTS = re.compile(r"^\[Parsed_showinfo.*? pts_time:(\S+)", re.MULTILINE)


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


def _run(command: list[str]):
    LOGGER.debug("Command: %s", " ".join(command))
    return subprocess.run(command, check=True, capture_output=True, text=True)


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


def video_encoder_args(bitrate: int, codec: FfmpegVideoCodec, realtime: bool) -> list[str]:
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
            missing_dependencies.append(f"The {video_filter} video filter is not supported by ffmpeg")
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

    def _wait_until_ready(self):
        pass

    def __enter__(self):
        self.start()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.stop()

    def is_running(self) -> bool:
        return self._process is not None and self._process.is_running()

    def restart(self):
        self.stop()
        self.start()

    def start(self):
        command = list(FFMPEG_COMMAND)
        if self._quiet:
            command += ["-nostats", "-loglevel", "warning"]
        command += self.args()
        self._process = ManagedProcess(
            command,
            LOGGER,
            stdin=subprocess.DEVNULL,
            log_level=_log_level,
            ready=self._wait_until_ready,
        )
        self._process.start()

    def stop(self):
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


class FfmpegAudioStream(FfmpegCommand):
    def __init__(self, url, source: str, transport_format=TransportFormat.FLV, quiet=False):
        super().__init__(quiet)
        self._url = url
        self._source = source
        self._transport_format = transport_format

    def args(self):
        return [
            "-re",
            "-f",
            "lavfi",
            "-i",
            self._source,
            "-c:a",
            "aac",
            "-b:a",
            "128k",
            "-f",
            self._transport_format,
            self._url,
        ]


class FfmpegAudioTestStream(FfmpegAudioStream):
    def __init__(self, url, transport_format=TransportFormat.FLV):
        super().__init__(
            url,
            "aevalsrc=exprs='if(lt(mod(t,1),0.015),0.8*sin(2*PI*1800*t)*exp(-80*mod(t,1)),0)':s=48000",
            transport_format,
        )


class FfmpegNoiseStream(FfmpegAudioStream):
    def __init__(self, url, transport_format=TransportFormat.FLV, amplitude: float = 0.5):
        super().__init__(
            url,
            f"anoisesrc=amplitude={amplitude}:sample_rate=48000",
            transport_format,
            quiet=True,
        )


def _holds_port(pid: int, transport: str, port: int) -> bool:
    proc = subprocess.run(
        ["lsof", "-nP", "-a", "-p", str(pid), f"-i{transport}:{port}"],
        check=False,
        capture_output=True,
        text=True,
    )
    return len(proc.stdout.splitlines()) > 1


class FfmpegServer(FfmpegCommand):
    def __init__(self, url: str, filename: Path):
        super().__init__()
        self._url = url
        self._filename = filename

    def args(self):
        listen = []
        if self._transport() == "TCP":
            listen = ["-listen", "1"]
        return [
            *listen,
            "-i",
            self._url,
            "-c",
            "copy",
            str(self._filename),
        ]

    def _transport(self) -> str:
        return "TCP" if urlsplit(self._url).scheme in ["rtmp", "rtmps"] else "UDP"

    def _wait_until_ready(self):
        port = urlsplit(self._url).port
        pid = self._process.pid() if self._process is not None else None
        if port is None or pid is None:
            return
        transport = self._transport()
        wait_until(
            lambda: self._is_listening(pid, transport, port),
            f"ffmpeg to listen on {transport} port {port}",
        )

    def _is_listening(self, pid: int, transport: str, port: int) -> bool:
        if not self.is_running():
            raise Exception(f"ffmpeg exited before it started to listen on {transport} port {port}")
        return _holds_port(pid, transport, port)


class StreamRecorder:
    def __init__(self, url: str, path: Path):
        self._url = url
        self._server: FfmpegServer | None = None
        self.file = path

    def __enter__(self):
        self._server = FfmpegServer(url=self._url, filename=self.file)
        self._server.start()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self._stop()

    def is_running(self) -> bool:
        return self._server is not None and self._server.is_running()

    def total_bytes(self) -> int:
        return file_size(self.file)

    def poll(self):
        if self._server is None or self._server.is_running():
            return
        LOGGER.warning("The stream recorder exited. No longer receiving the stream.")
        self._stop()

    def _stop(self):
        if self._server is not None:
            self._server.stop()
            self._server = None


def file_size(path: Path) -> int:
    try:
        return path.stat().st_size
    except OSError:
        return 0


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
    output = ffprobe_run(path, "-select_streams", "v:0", "-show_entries", "stream=width,height")
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
class QrCode:
    number: int
    pts: float

    def __init__(self, text: str):
        parts = text.split(" ")
        if len(parts) == 4:
            self.number = int(parts[1])
            self.pts = float(parts[3])
        else:
            self.number = -1
            self.pts = -1


def _decode_qr_code(file: Path) -> QrCode:
    proc = subprocess.run(["qrtool", "decode", str(file)], check=False, capture_output=True, text=True)
    return QrCode(proc.stdout)


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
    with ThreadPoolExecutor(max_workers=32) as executor:
        qr_codes = list(executor.map(_decode_qr_code, sorted(qr_codes_dir.iterdir())))
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


@dataclass
class VideoRegionColors:
    pts: float
    colors: list[Pixel]


def read_video_region_colors(
    path: Path,
    crop: Crop,
    columns: int,
    rows: int,
    start: float,
    duration: float,
) -> list[VideoRegionColors]:
    command = FFMPEG_COMMAND + [
        "-ss",
        f"{start:.3f}",
        "-t",
        f"{duration:.3f}",
        "-i",
        str(path),
        "-an",
        "-vf",
        f"crop=x={crop.x}:y={crop.y}:w={crop.width}:h={crop.height},"
        f"format=rgb24,scale={columns}:{rows}:flags=area,showinfo",
        "-fps_mode",
        "passthrough",
        "-f",
        "rawvideo",
        "-pix_fmt",
        "rgb24",
        "-",
    ]
    LOGGER.debug("Command: %s", " ".join(command))
    proc = subprocess.run(command, check=True, capture_output=True)
    presentation_time_stamps = [
        float(pts) for pts in RE_SHOWINFO_PTS.findall(proc.stderr.decode("utf-8", "replace"))
    ]
    frame_size = 3 * columns * rows
    frames = []
    for index, pts in enumerate(presentation_time_stamps):
        data = proc.stdout[index * frame_size : (index + 1) * frame_size]
        if len(data) < frame_size:
            break
        colors = [Pixel(*data[offset : offset + 3]) for offset in range(0, frame_size, 3)]
        frames.append(VideoRegionColors(start + pts, colors))
    return frames


def measure_mean_volume(path: Path) -> float:
    return _measure_volume(path, "mean_volume", None)


def measure_max_volume(path: Path, audio_filters: list[str] | None = None) -> float:
    return _measure_volume(path, "max_volume", audio_filters)


def _measure_volume(path: Path, name: str, audio_filters: list[str] | None) -> float:
    output = ffmpeg_run(
        "-i",
        str(path),
        "-vn",
        "-af",
        _audio_filter_chain(audio_filters, "volumedetect"),
        "-f",
        "null",
        "-",
    ).stderr
    for found_name, value in RE_VOLUME_DETECT.findall(output):
        if found_name == name:
            return float(value)
    return -math.inf


def _audio_filter_chain(audio_filters: list[str] | None, *extra: str) -> str:
    return ",".join([*(audio_filters or []), *extra])


def detect_audio_onsets(
    path: Path,
    noise_db: float,
    minimum_silence: float,
    audio_filters: list[str] | None = None,
) -> list[float]:
    output = ffmpeg_run(
        "-i",
        str(path),
        "-vn",
        "-af",
        _audio_filter_chain(audio_filters, f"silencedetect=noise={noise_db}dB:duration={minimum_silence}"),
        "-f",
        "null",
        "-",
    ).stderr
    return [float(value) for kind, value in RE_SILENCE_DETECT.findall(output) if kind == "end"]


@dataclass
class Silence:
    start: float
    end: float


def detect_silence(path: Path, noise_db: float, minimum_duration: float) -> list[Silence]:
    output = ffmpeg_run(
        "-i",
        str(path),
        "-vn",
        "-af",
        f"silencedetect=noise={noise_db}dB:duration={minimum_duration}",
        "-f",
        "null",
        "-",
    ).stderr
    silences = []
    start = None
    for kind, value in RE_SILENCE_DETECT.findall(output):
        if kind == "start":
            start = float(value)
        elif start is not None:
            silences.append(Silence(start, float(value)))
            start = None
    if start is not None:
        silences.append(Silence(start, ffprobe_format(path).duration))
    return silences


def extract_ltc_wav(path: Path, output: Path):
    ffmpeg_run("-i", str(path), "-vn", "-map", "0:a:0", "-c:a", "pcm_s16le", str(output))


def read_unique_frame_presentation_time_stamps(path: Path, crop: Crop | None = None) -> list[float]:
    filters = []
    if crop is not None:
        filters.append(f"crop=x={crop.x}:y={crop.y}:w={crop.width}:h={crop.height}")
    filters += ["mpdecimate", "showinfo"]
    output = ffmpeg_run(
        "-i",
        str(path),
        "-vf",
        ", ".join(filters),
        "-fps_mode",
        "vfr",
        "-an",
        "-f",
        "null",
        "-",
    ).stderr
    return [float(pts) for pts in RE_SHOWINFO_PTS.findall(output)]


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
