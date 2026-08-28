import subprocess
from dataclasses import dataclass
from datetime import UTC
from datetime import datetime
from logging import Logger
from pathlib import Path
from urllib.parse import urlsplit

TEST_DIR = Path(__file__).parent.parent.resolve()
WEBSITES_DIR = TEST_DIR / "suites" / "websites"
FILES_DIR = TEST_DIR / "files"
BLACK_MAXIMUM_VALUE = 40


@dataclass
class Range:
    minimum: float
    maximum: float


def manual_validation(logger: Logger, message: str):
    logger.info("🧪: %s", message)


def manual_requirement(logger: Logger, message: str):
    logger.info("👷‍♂️: %s", message)


def manual_volume_requirement(logger: Logger):
    manual_requirement(logger, "Keep the volume turned up so the microphones pick up played sounds")


def manual_confirmation(message: str):
    input(f"🧑‍🔧: {message} Press ENTER to continue.")


@dataclass
class Crop:
    x: int
    y: int
    width: int
    height: int


@dataclass
class Pixel:
    red: int
    green: int
    blue: int

    def is_black(self) -> bool:
        return max(self.red, self.green, self.blue) <= BLACK_MAXIMUM_VALUE


class Image:
    """A RGB image, typically a cropped part of a video frame."""

    def __init__(self, width: int, height: int, data: bytes):
        self.width = width
        self.height = height
        self._data = data

    def pixel(self, x: int, y: int) -> Pixel:
        offset = 3 * (self.width * y + x)
        return Pixel(*self._data[offset : offset + 3])

    def contains(self, x: int, y: int) -> bool:
        return 0 <= x < self.width and 0 <= y < self.height

    def is_all_black(self) -> bool:
        return max(self._data, default=0) <= BLACK_MAXIMUM_VALUE

    def find_non_black_pixel(self) -> tuple[int, int] | None:
        for y in range(self.height):
            for x in range(self.width):
                if not self.pixel(x, y).is_black():
                    return x, y
        return None

    def non_black_ratio(self) -> float:
        non_black = sum(
            1
            for offset in range(0, len(self._data), 3)
            if max(self._data[offset : offset + 3]) > BLACK_MAXIMUM_VALUE
        )
        return non_black / (self.width * self.height)


def create_qr_code_image(text: str, output_image: Path):
    command = ["qrtool", "encode", "--output", str(output_image), text]
    subprocess.run(command, check=True)


def format_generic_stream_url_stream_name(number: int, url: str) -> str:
    urlparts = urlsplit(url)
    return f"Generic {number} ({urlparts.scheme}://{urlparts.netloc})"


def anchor_time_of_day(seconds: float, start: datetime) -> float:
    midnight = datetime(start.year, start.month, start.day, tzinfo=UTC).timestamp() + seconds
    for offset in (-86400, 0, 86400):
        if abs(midnight + offset - start.timestamp()) < 43200:
            return midnight + offset
    return midnight


def slope_per_hour(points: list[tuple[float, float]]) -> float:
    if len(points) < 2:
        return 0.0
    mean_x = sum(x for x, _ in points) / len(points)
    mean_y = sum(y for _, y in points) / len(points)
    numerator = sum((x - mean_x) * (y - mean_y) for x, y in points)
    denominator = sum((x - mean_x) ** 2 for x, _ in points)
    if denominator == 0:
        return 0.0
    return 3600 * numerator / denominator
