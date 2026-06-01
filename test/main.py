import argparse
import systest
from tests.stream import StreamRtmpFromMoblinToMediaMtx
from tests.stream import StreamSrtFromMoblinToMediaMtx
from tests.ingests import AllIngestsInParallel
from utils.moblin import Moblin


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--moblin-ip-address", required=True)
    parser.add_argument(
        "--tester-ip-address",
        required=True,
        help="The IP address of the machine that runs the test suite.",
    )
    parser.add_argument("--remote-control-port", type=int, default=2345)
    parser.add_argument("--remote-control-password", default="1234")
    sequencer = systest.setup("main", parser)
    args = parser.parse_args()
    moblin = Moblin(args.remote_control_port, args.remote_control_password)
    with moblin:
        sequencer.run(
            StreamRtmpFromMoblinToMediaMtx(moblin),
            StreamSrtFromMoblinToMediaMtx(moblin),
            AllIngestsInParallel(moblin),
        )
    sequencer.report_and_exit()


main()
