import argparse

from suites import stability
from suites.stability import Ingest

from utils.runner import create_parser
from utils.runner import run
from utils.traffic_shaper import ProfileName


def parse_ingests(value: str) -> list[Ingest]:
    ingests = []
    for name in value.split(","):
        try:
            ingest = Ingest(name.strip().lower())
        except ValueError:
            choices = ", ".join(Ingest)
            raise argparse.ArgumentTypeError(
                f"'{name}' is not one of {choices}"
            ) from None
        if ingest not in ingests:
            ingests.append(ingest)
    if len(ingests) == 0:
        raise argparse.ArgumentTypeError("at least one ingest must be given")
    return ingests


def create_suites(moblin, args):
    shaper = stability.create_traffic_shaper(
        moblin.config,
        args.stream_traffic_shaping_profile,
        args.stream_traffic_shaping_parameters,
        args.ingests_traffic_shaping_profile,
        args.ingests_traffic_shaping_parameters,
    )
    return [stability.tests(moblin, args.ingests, 3600 * args.duration, shaper)]


def main():
    parser = create_parser("Run the app for a long time and monitor it.")
    parser.add_argument(
        "--duration",
        type=float,
        default=12,
        help="Duration in hours (default: %(default)s).",
    )
    parser.add_argument(
        "--ingests",
        type=parse_ingests,
        default=list(Ingest),
        help="Comma separated list of ingests to stream to, for example 'rtmp,whep' "
        "(default: all).",
    )
    parser.add_argument(
        "--stream-traffic-shaping-profile",
        type=ProfileName,
        choices=list(ProfileName),
        help="Traffic shaping profile of the outgoing stream.",
    )
    parser.add_argument(
        "--stream-traffic-shaping-parameters",
        help="Traffic shaping parameters of the outgoing stream, for example "
        "'rate=3Mbit,delay=60,loss=0.5'.",
    )
    parser.add_argument(
        "--ingests-traffic-shaping-profile",
        type=ProfileName,
        choices=list(ProfileName),
        help="Traffic shaping profile of the ingests.",
    )
    parser.add_argument(
        "--ingests-traffic-shaping-parameters",
        help="Traffic shaping parameters of the ingests, for example "
        "'low-rate=10Mbit,high-rate=25Mbit,period=120'.",
    )
    run("stability", parser, create_suites)


main()
