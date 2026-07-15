import argparse
import logging
from pathlib import Path

import systest
from tests import browser_widget
from tests import ingests
from tests import record
from tests import scenes
from tests import stream
from tests import talkback
from tests import web_remote_control

from utils.config import Config
from utils.dependencies import check_dependencies
from utils.moblin import Arduino
from utils.moblin import Moblin


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("config_toml", type=Path)
    parser.add_argument("--device")
    parser.add_argument("--moving-picture", action="store_true")
    parser.add_argument("--arduino-serial-port")
    sequencer = systest.setup("main", parser, add_date_to_log_filename=False)
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
        moblin.set_scene("Front")
        moblin.end()
        moblin.stop_recording()
        sequencer.run(
            talkback.tests(moblin),
            ingests.tests(moblin),
            record.tests(moblin),
            scenes.tests(moblin),
            stream.tests(moblin),
            browser_widget.tests(moblin),
            web_remote_control.tests(moblin),
        )
    sequencer.report_and_exit(json=False, dot=False)


main()
