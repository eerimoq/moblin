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
