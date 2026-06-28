import argparse
import logging
import tomllib
from pathlib import Path
import systest
from tests.talkback import Talkback
from tests.stream import StreamRtmpFromMoblinToMediaMtx
from tests.stream import StreamMultiRtmpFromMoblinToMediaMtx
from tests.stream import StreamSrtFromMoblinToMediaMtx
from tests.scenes import SceneSwitchMultipleTimes
from tests.ingests import StreamToRtmpServerIngest
from tests.record import RecordH264
from tests.record import RecordH265
from utils.moblin import Moblin


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("config_toml", type=Path)
    parser.add_argument("--device", required=False)
    sequencer = systest.setup("main", parser)
    args = parser.parse_args()
    logging.getLogger("urllib3.connectionpool").setLevel(logging.INFO)
    config = tomllib.loads(args.config_toml.read_text())
    general = config["general"]
    if args.device:
        general["device"] = args.device
    device = config["device"][general["device"]]
    moblin = Moblin(
        general["remote-control-port"],
        device["moblin-ip-address"],
    )
    with moblin:
        moblin.set_scene("Front")
        moblin.end()
        moblin.stop_recording()
        sequencer.run(
            RecordH264(moblin),
            RecordH265(moblin),
            SceneSwitchMultipleTimes(moblin),
            StreamRtmpFromMoblinToMediaMtx(moblin),
            StreamSrtFromMoblinToMediaMtx(moblin),
            StreamMultiRtmpFromMoblinToMediaMtx(moblin),
            StreamToRtmpServerIngest(moblin),
            Talkback(moblin),
        )
    sequencer.report_and_exit()


main()
