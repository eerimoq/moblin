import argparse
import logging
from pathlib import Path
import systest
from tests import talkback
from tests import stream
from tests import scenes
from tests import ingests
from tests import record
from tests import browser_widget
from utils.config import Config
from utils.moblin import Moblin
from utils.dependencies import check_dependencies


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("config_toml", type=Path)
    parser.add_argument("--device", required=False)
    sequencer = systest.setup("main", parser, add_date_to_log_filename=False)
    args = parser.parse_args()
    check_dependencies()
    logging.getLogger("urllib3.connectionpool").setLevel(logging.INFO)
    config = Config(args.config_toml, args.device)
    moblin = Moblin(config)
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
        )
    sequencer.report_and_exit()


main()
