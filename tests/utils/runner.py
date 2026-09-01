import argparse
import logging
import shutil
import textwrap
from collections.abc import Callable

import systest

from .arduino import Arduino
from .config import Config
from .dependencies import check_dependencies
from .moblin import Moblin
from .utils import FILES_DIR
from .utils import TEST_DIR

MakeTests = Callable[[Moblin, argparse.Namespace], list]


class HelpFormatter(argparse.HelpFormatter):
    def _split_lines(self, text: str, width: int) -> list[str]:
        lines = []
        for line in text.splitlines():
            indent = " " * (len(line) - len(line.lstrip()) + 2)
            lines += textwrap.wrap(line, width, subsequent_indent=indent) or [""]
        return lines


def create_parser(description: str) -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=description, formatter_class=HelpFormatter)
    parser.add_argument("--device", required=True)
    parser.add_argument("--arduino-serial-port")
    parser.add_argument("--moving-picture", action="store_true")
    parser.add_argument(
        "--dji-camera",
        action="store_true",
        help="Run all tests that requires a DJI camera.",
    )
    parser.add_argument(
        "--interactive",
        action="store_true",
        help="Run all tests that requires user interaction.",
    )
    return parser


def _remove_previous_run_artifacts(name: str):
    shutil.rmtree(FILES_DIR, ignore_errors=True)
    FILES_DIR.mkdir(parents=True)
    (TEST_DIR / "logs" / f"{name}.log").unlink(missing_ok=True)


def run(name: str, parser: argparse.ArgumentParser, make_tests: MakeTests):
    _remove_previous_run_artifacts(name)
    sequencer = systest.setup(name, parser, add_date_to_log_filename=False)
    sequencer.remove_filtered_testcases = True
    sequencer.compact_output = True
    args = parser.parse_args()
    check_dependencies()
    logging.getLogger("urllib3.connectionpool").setLevel(logging.INFO)
    logging.getLogger("websockets.client").setLevel(logging.INFO)
    config = Config()
    if args.arduino_serial_port:
        arduino = Arduino(args.arduino_serial_port)
    else:
        arduino = None
    moblin = Moblin(
        config,
        args.device,
        arduino,
        args.moving_picture,
        args.dji_camera,
        args.interactive,
    )
    with moblin:
        moblin.end()
        moblin.stop_recording()
        moblin.delete_all_recordings()
        sequencer.run(*make_tests(moblin, args))
    sequencer.report_and_exit(json=False, dot=False)
