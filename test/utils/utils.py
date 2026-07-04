import logging
import subprocess
import threading
from dataclasses import dataclass
from logging import Logger
from pathlib import Path


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


@dataclass
class Crop:
    x: int
    y: int
    width: int
    height: int


WEBSITES_ROOT = Path(__file__).parent.parent.resolve() / "tests" / "websites"


def create_qr_code_image(text: str, output_image: Path):
    command = [
        "qrtool",
        "encode",
        "--output",
        str(output_image),
        text,
    ]
    subprocess.run(command, check=True)
