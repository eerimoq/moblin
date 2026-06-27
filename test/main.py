import argparse
import logging
import tomllib
from pathlib import Path
import systest
from tests.stream import StreamRtmpFromMoblinToMediaMtx
from tests.stream import StreamMultiRtmpFromMoblinToMediaMtx
from tests.stream import StreamSrtFromMoblinToMediaMtx
from tests.scenes import SceneSwitchMultipleTimes
from tests.ingests import StreamToRtmpIngest
from tests.record import RecordH264
from tests.record import RecordH265
from utils.moblin import Moblin


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("config_toml", type=Path)
    sequencer = systest.setup("main", parser)
    args = parser.parse_args()
    logging.getLogger("urllib3.connectionpool").setLevel(logging.INFO)
    config = tomllib.loads(args.config_toml.read_text())
    general = config["general"]
    device = config["device"][general["device"]]
    moblin = Moblin(
        general["remote-control-port"],
        device["moblin-ip-address"],
    )
    with moblin:
        sequencer.run(
            RecordH264(moblin),
            RecordH265(moblin),
            SceneSwitchMultipleTimes(moblin),
            StreamRtmpFromMoblinToMediaMtx(moblin),
            StreamSrtFromMoblinToMediaMtx(moblin),
            StreamMultiRtmpFromMoblinToMediaMtx(moblin),
            StreamToRtmpIngest(moblin),
            # Talkback.
            # One test per ingest type?
            # Widgets?
            # High load tests.
            # Should we validate the received video and audio somehow? for example validate codecs?
            # Browser widget access level test.
        )
    sequencer.report_and_exit()


main()
