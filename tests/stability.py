from suites import stability

from utils.runner import create_parser
from utils.runner import run


def create_suites(moblin, args):
    shaper = stability.create_traffic_shaper(
        moblin.config, args.stream_traffic_shaping, args.ingests_traffic_shaping
    )
    return [stability.tests(moblin, 3600 * args.duration, shaper)]


def main():
    parser = create_parser("Run the app for a long time and monitor it.")
    parser.add_argument(
        "--duration",
        type=float,
        default=stability.DEFAULT_DURATION / 3600,
        help="Duration in hours (default: %(default)s).",
    )
    parser.add_argument(
        "--stream-traffic-shaping",
        help="Traffic shaping of the outgoing stream, for example "
        "'profile=constant,rate=3Mbit,delay=60,loss=0.5'.",
    )
    parser.add_argument(
        "--ingests-traffic-shaping",
        help="Traffic shaping of the ingests, for example "
        "'profile=square,low-rate=10Mbit,high-rate=25Mbit,period=120'.",
    )
    run("stability", parser, create_suites)


main()
