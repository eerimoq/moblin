import argparse
import tomllib
from pathlib import Path
import systest
from tests.stream import StreamRtmpFromMoblinToMediaMtx
from tests.stream import StreamSrtFromMoblinToMediaMtx

# from tests.ingests import AllIngestsInParallel
from utils.moblin import Moblin


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("config_toml", type=Path)
    sequencer = systest.setup("main", parser)
    args = parser.parse_args()
    config = tomllib.loads(args.config_toml.read_text())
    general = config["general"]
    moblin = Moblin(general["remote-control-port"], general["remote-control-password"])
    with moblin:
        sequencer.run(
            StreamRtmpFromMoblinToMediaMtx(moblin),
            StreamSrtFromMoblinToMediaMtx(moblin),
            # AllIngestsInParallel(moblin),
        )
    sequencer.report_and_exit()


main()
