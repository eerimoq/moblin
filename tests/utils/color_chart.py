import math
import struct
import subprocess
from dataclasses import dataclass
from pathlib import Path

from systest_moblin.ffmpeg import ffprobe_run

from .utils import write_png

WIDTH = 1920
HEIGHT = 1080
COLUMNS = 12
ROWS = 6
PATCH_WIDTH = WIDTH // COLUMNS
PATCH_HEIGHT = HEIGHT // ROWS
DISPLAY_P3_TO_SRGB = [
    [1.2249401, -0.2249404, 0.0],
    [-0.0420569, 1.0420571, 0.0],
    [-0.0196376, -0.0786361, 1.0982735],
]
BT2020_TO_SRGB = [
    [1.660491, -0.587641, -0.072850],
    [-0.124550, 1.132900, -0.008349],
    [-0.018151, -0.100579, 1.118730],
]
HLG_A = 0.17883277
HLG_B = 0.28466892
HLG_C = 0.55991073
HLG_REFERENCE_WHITE = 203 / 1000
LUMA_COEFFICIENTS = {
    "bt709": (0.2126, 0.0722),
    "smpte170m": (0.299, 0.114),
    "bt470bg": (0.299, 0.114),
    "bt2020nc": (0.2627, 0.0593),
}
PIXEL_FORMAT_BITS = {
    "yuv420p": 8,
    "yuvj420p": 8,
    "yuv420p10le": 10,
}
DEFAULT_COLOR_TAGS = {
    "color_range": "pc",
    "color_space": "smpte170m",
    "color_primaries": "bt709",
    "color_transfer": "bt709",
}
LIMITED_COLOR_TAGS = {
    "color_range": "tv",
    "color_space": "bt709",
    "color_primaries": "bt709",
    "color_transfer": "bt709",
}


def _scaled(level: float) -> list[tuple[int, int, int]]:
    v = round(255 * level)
    return [(v, 0, 0), (0, v, 0), (0, 0, v), (0, v, v), (v, 0, v), (v, v, 0)]


PATCHES = (
    [(v, v, v) for v in (0, 8, 16, 32, 64, 96, 128, 160, 192, 224, 240, 255)]
    + _scaled(1.0)
    + _scaled(0.75)
    + _scaled(0.5)
    + _scaled(0.25)
    + [
        (255, 128, 0),
        (128, 0, 255),
        (0, 128, 128),
        (255, 105, 180),
        (139, 69, 19),
        (0, 0, 128),
        (128, 128, 0),
        (4, 4, 4),
        (250, 250, 250),
        (135, 206, 235),
        (255, 220, 177),
        (60, 40, 30),
    ]
    + [
        (115, 82, 68),
        (194, 150, 130),
        (98, 122, 157),
        (87, 108, 67),
        (133, 128, 177),
        (103, 189, 170),
        (214, 126, 44),
        (80, 91, 166),
        (193, 90, 99),
        (94, 60, 108),
        (157, 188, 64),
        (224, 163, 46),
    ]
    + [
        (56, 61, 150),
        (70, 148, 73),
        (175, 54, 60),
        (231, 199, 31),
        (187, 86, 149),
        (8, 133, 161),
        (243, 243, 242),
        (200, 200, 200),
        (160, 160, 160),
        (122, 122, 121),
        (85, 85, 85),
        (52, 52, 52),
    ]
)


@dataclass
class ChartErrors:
    mean: float
    maximum: float
    worst_expected: tuple[int, int, int]
    worst_actual: tuple[float, float, float]

    def __str__(self) -> str:
        actual = tuple(round(value) for value in self.worst_actual)
        return f"mean {self.mean:.1f}, max {self.maximum:.1f} (expected {self.worst_expected}, got {actual})"


def write_color_chart(path: Path):
    rgba = bytearray()
    for y in range(HEIGHT):
        row = y // PATCH_HEIGHT
        for column in range(COLUMNS):
            rgba += bytes([*PATCHES[row * COLUMNS + column], 255]) * PATCH_WIDTH
    write_png(path, WIDTH, HEIGHT, bytes(rgba))


def read_patch_colors(path: Path, timestamp: float, scale: float = 1.0) -> list[tuple[float, float, float]]:
    stream = ffprobe_run(path, "-select_streams", "v:0", "-show_streams")["streams"][0]
    pix_fmt = stream["pix_fmt"]
    if pix_fmt not in PIXEL_FORMAT_BITS:
        raise Exception(f"Unsupported pixel format {pix_fmt}")
    matrix = stream.get("color_space")
    if matrix not in LUMA_COEFFICIENTS:
        raise Exception(f"Unsupported color matrix {matrix}")
    width = stream["width"]
    height = stream["height"]
    bits = PIXEL_FORMAT_BITS[pix_fmt]
    data = subprocess.run(
        [
            "ffmpeg",
            "-v",
            "error",
            "-ss",
            str(timestamp),
            "-i",
            str(path),
            "-frames:v",
            "1",
            "-f",
            "rawvideo",
            "-pix_fmt",
            pix_fmt,
            "-",
        ],
        capture_output=True,
        check=True,
    ).stdout
    if len(data) != width * height * 3 // 2 * (2 if bits > 8 else 1):
        raise Exception(f"No video frame at {timestamp} seconds in {path}")
    values = struct.unpack(f"<{len(data) // 2}H", data) if bits > 8 else data
    luma = values[: width * height]
    blue_difference = values[width * height : width * height * 5 // 4]
    red_difference = values[width * height * 5 // 4 : width * height * 3 // 2]
    red_coefficient, blue_coefficient = LUMA_COEFFICIENTS[matrix]
    green_coefficient = 1 - red_coefficient - blue_coefficient
    step = 1 << (bits - 8)
    maximum = (1 << bits) - 1
    patch_width = int(PATCH_WIDTH * scale)
    patch_height = int(PATCH_HEIGHT * scale)
    colors = []
    for index in range(len(PATCHES)):
        x0 = (index % COLUMNS) * patch_width + patch_width // 4
        y0 = (index // COLUMNS) * patch_height + patch_height // 4
        x1 = x0 + patch_width // 2
        y1 = y0 + patch_height // 2
        y = sum(luma[row * width + column] for row in range(y0, y1) for column in range(x0, x1)) / (
            (x1 - x0) * (y1 - y0)
        )
        chroma = [
            row * width // 2 + column for row in range(y0 // 2, y1 // 2) for column in range(x0 // 2, x1 // 2)
        ]
        cb = sum(blue_difference[i] for i in chroma) / len(chroma)
        cr = sum(red_difference[i] for i in chroma) / len(chroma)
        if stream.get("color_range") == "pc":
            y, cb, cr = y / maximum, (cb - (1 << (bits - 1))) / maximum, (cr - (1 << (bits - 1))) / maximum
        else:
            y, cb, cr = (
                (y - 16 * step) / (219 * step),
                (cb - 128 * step) / (224 * step),
                (cr - 128 * step) / (224 * step),
            )
        red = y + 2 * (1 - red_coefficient) * cr
        blue = y + 2 * (1 - blue_coefficient) * cb
        green = (y - red_coefficient * red - blue_coefficient * blue) / green_coefficient
        colors.append((255 * red, 255 * green, 255 * blue))
    return colors


def _srgb_to_linear(value: float) -> float:
    value /= 255
    return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4


def _linear_to_srgb(value: float) -> float:
    value = min(max(value, 0.0), 1.0)
    return 255 * (12.92 * value if value <= 0.0031308 else 1.055 * value ** (1 / 2.4) - 0.055)


def display_p3_to_srgb(color: tuple[float, float, float]) -> tuple[float, float, float]:
    linear = [_srgb_to_linear(value) for value in color]
    red, green, blue = (
        _linear_to_srgb(sum(factor * value for factor, value in zip(row, linear, strict=True)))
        for row in DISPLAY_P3_TO_SRGB
    )
    return (red, green, blue)


def _hlg_inverse_oetf(value: float) -> float:
    if value <= 0.5:
        return value * value / 3
    return (math.exp((value - HLG_C) / HLG_A) + HLG_B) / 12


def hlg_to_srgb(color: tuple[float, float, float]) -> tuple[float, float, float]:
    scene = [_hlg_inverse_oetf(value / 255) for value in color]
    luminance = 0.2627 * scene[0] + 0.6780 * scene[1] + 0.0593 * scene[2]
    gain = luminance**0.2 / HLG_REFERENCE_WHITE if luminance > 0 else 0.0
    display = [gain * value for value in scene]
    red, green, blue = (
        _linear_to_srgb(sum(factor * value for factor, value in zip(row, display, strict=True)))
        for row in BT2020_TO_SRGB
    )
    return (red, green, blue)


def measure_chart_errors(colors: list[tuple[float, float, float]]) -> ChartErrors:
    errors = []
    for expected, actual in zip(PATCHES, colors, strict=True):
        error = sum((a - e) ** 2 for a, e in zip(actual, expected, strict=True)) ** 0.5
        errors.append((error, expected, actual))
    worst = max(errors)
    return ChartErrors(sum(error for error, _, _ in errors) / len(errors), worst[0], worst[1], worst[2])


def gray_ramp(colors: list[tuple[float, float, float]]) -> list[tuple[float, float, float]]:
    return [color for color, patch in zip(colors, PATCHES, strict=True) if patch[0] == patch[1] == patch[2]][
        :COLUMNS
    ]


def read_color_tags(path: Path) -> dict[str, str | None]:
    stream = ffprobe_run(path, "-select_streams", "v:0", "-show_streams")["streams"][0]
    return {key: stream.get(key) for key in DEFAULT_COLOR_TAGS}


def read_frames_color_tags(path: Path) -> list[dict[str, str | None]]:
    frames = ffprobe_run(
        path,
        "-select_streams",
        "v:0",
        "-show_entries",
        "frame=" + ",".join(DEFAULT_COLOR_TAGS),
    )["frames"]
    unique_tags = {tuple(frame.get(key) for key in DEFAULT_COLOR_TAGS) for frame in frames}
    return [dict(zip(DEFAULT_COLOR_TAGS, tags, strict=True)) for tags in unique_tags]
