import logging
import subprocess
import threading
from dataclasses import dataclass
from logging import Logger
from pathlib import Path
from urllib.parse import urlsplit

WEBSITES_ROOT = Path(__file__).parent.parent.resolve() / "tests" / "websites"
# Video encoding never makes black pixels perfectly black.
BLACK_MAXIMUM_VALUE = 40


def _log_stream(stream, logger: Logger, log_level):
    try:
        for line in stream:
            line = line.rstrip()
            logger.log(log_level(line), line)
    except Exception:
        pass


def _log_level(_line: str) -> int:
    return logging.DEBUG


def log_output(stream, logger, log_level=_log_level):
    threading.Thread(
        target=_log_stream, args=(stream, logger, log_level), daemon=True
    ).start()


def manual_validation(logger: Logger, message: str):
    logger.info("🧪🧪🧪 Manual validation: %s 🧪🧪🧪", message)


def manual_confirmation(message: str):
    input(f"🧑‍🔧🧑‍🔧🧑‍🔧 {message} Press ENTER to continue. 🧑‍🔧🧑‍🔧🧑‍🔧")


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
    command = [
        "qrtool",
        "encode",
        "--output",
        str(output_image),
        text,
    ]
    subprocess.run(command, check=True)


def format_generic_stream_url_stream_name(number: int, url: str) -> str:
    urlparts = urlsplit(url)
    return f"Generic {number} ({urlparts.scheme}://{urlparts.netloc})"
