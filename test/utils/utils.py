from dataclasses import dataclass
from logging import Logger
import logging
import threading


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
