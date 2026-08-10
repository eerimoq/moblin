import argparse
import logging
import shutil
from collections.abc import Callable
from pathlib import Path

import systest

from .arduino import Arduino
from .config import Config
from .dependencies import check_dependencies
from .moblin import Moblin
from .utils import FILES_DIR
from .utils import TEST_DIR

MakeTests = Callable[[Moblin, argparse.Namespace], list]


def create_parser(description: str | None = None) -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=description)
    parser.add_argument("config_toml", type=Path)
    parser.add_argument("--device")
    parser.add_argument("--moving-picture", action="store_true")
    parser.add_argument("--arduino-serial-port")
    return parser


def _remove_previous_run_artifacts(name: str):
    shutil.rmtree(FILES_DIR, ignore_errors=True)
    FILES_DIR.mkdir(parents=True)
    (TEST_DIR / "logs" / f"{name}.log").unlink(missing_ok=True)


def run(name: str, parser: argparse.ArgumentParser, make_tests: MakeTests):
    _remove_previous_run_artifacts(name)
    sequencer = systest.setup(name, parser, add_date_to_log_filename=False)
    sequencer.remove_filtered_testcases = True
    args = parser.parse_args()
    check_dependencies()
    logging.getLogger("urllib3.connectionpool").setLevel(logging.INFO)
    config = Config(args.config_toml, args.device)
    if args.arduino_serial_port:
        arduino = Arduino(args.arduino_serial_port)
    else:
        arduino = None
    moblin = Moblin(config, arduino, args.moving_picture)
    with moblin:
        moblin.end()
        moblin.stop_recording()
        sequencer.run(*make_tests(moblin, args))
    sequencer.report_and_exit(json=False, dot=False)
