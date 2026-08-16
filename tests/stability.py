import argparse

from suites import stability
from suites.stability import Ingest

from utils.generate_device_settings import BitrateRateControl
from utils.runner import create_parser
from utils.runner import run
from utils.traffic_shaper import Profile
from utils.traffic_shaper import parse_profile


def parse_ingests(value: str) -> list[Ingest]:
    ingests: list[Ingest] = []
    if value.strip() == "":
        return ingests
    for name in value.split(","):
        try:
            ingest = Ingest(name.strip().lower())
        except ValueError:
            choices = ", ".join(Ingest)
            raise argparse.ArgumentTypeError(f"'{name}' is not one of {choices}") from None
        if ingest not in ingests:
            ingests.append(ingest)
    return ingests


def parse_video_bitrate_control(value: str) -> BitrateRateControl:
    try:
        return BitrateRateControl(value.strip().upper())
    except ValueError:
        choices = ", ".join(BitrateRateControl)
        raise argparse.ArgumentTypeError(f"'{value}' is not one of {choices}") from None


def parse_traffic_shaping(value: str) -> Profile:
    try:
        return parse_profile(value)
    except Exception as error:
        raise argparse.ArgumentTypeError(str(error)) from None


def create_suites(moblin, args):
    shaper = stability.create_traffic_shaper(
        moblin.config,
        args.stream_traffic_shaping,
        args.ingests_traffic_shaping,
    )
    return [
        stability.tests(
            moblin,
            args.ingests,
            not args.no_stream,
            not args.no_record,
            3600 * args.duration,
            shaper,
            args.video_bitrate_control,
            args.network_capture,
        )
    ]


def main():
    parser = create_parser("Run the app for a long time and monitor it.")
    parser.add_argument(
        "-d", "--duration",
        type=float,
        default=8,
        help="Duration in hours (default: %(default)s).",
    )
    parser.add_argument(
        "--ingests",
        type=parse_ingests,
        default=list(Ingest),
        help="Comma separated list of ingests to stream to, for example 'rtmp,whep'. "
        "Give an empty list to disable all ingests (default: all).",
    )
    parser.add_argument(
        "--no-stream",
        action="store_true",
        help="Do not start the outgoing stream, only run the ingests.",
    )
    parser.add_argument(
        "--no-record",
        action="store_true",
        help="Do not record to disk in the app.",
    )
    parser.add_argument(
        "--video-bitrate-control",
        type=parse_video_bitrate_control,
        choices=list(BitrateRateControl),
        default=BitrateRateControl.ABR,
        help="Video bitrate control (default: %(default)s).",
    )
    parser.add_argument(
        "--network-capture",
        action="store_true",
        help="Capture the packets to and from the device to a pcap file for the whole test run.",
    )
    parser.add_argument(
        "-s",
        "--stream-traffic-shaping",
        type=parse_traffic_shaping,
        help="Traffic shaping of the outgoing stream as '<profile>,<name>=<value>,...', "
        "for example 'constant,rate=3,delay=60,loss=0.5'. Rates are in Mbps.",
    )
    parser.add_argument(
        "-i",
        "--ingests-traffic-shaping",
        type=parse_traffic_shaping,
        help="Traffic shaping of each ingest as '<profile>,<name>=<value>,...', "
        "for example 'square,low-rate=10,high-rate=25,period=120'. Rates are in Mbps.",
    )
    run("stability", parser, create_suites)


main()
