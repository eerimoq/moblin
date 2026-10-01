import argparse

from .suites import stability
from .suites.stability import Ingest
from .suites.stability import StreamProtocol
from .utils.generate_device_settings import BitrateRateControl
from .utils.runner import create_parser
from .utils.runner import run


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


def parse_stream_protocol(value: str) -> StreamProtocol:
    try:
        return StreamProtocol(value.strip().lower())
    except ValueError:
        choices = ", ".join(StreamProtocol)
        raise argparse.ArgumentTypeError(f"'{value}' is not one of {choices}") from None


def parse_video_bitrate_control(value: str) -> BitrateRateControl:
    try:
        return BitrateRateControl(value.strip().upper())
    except ValueError:
        choices = ", ".join(BitrateRateControl)
        raise argparse.ArgumentTypeError(f"'{value}' is not one of {choices}") from None


def create_suites(moblin, args):
    return [
        stability.tests(
            moblin,
            args.ingests,
            args.stream_protocol,
            3600 * args.duration,
            args.video_bitrate_control,
            args.network_capture,
        )
    ]


def main():
    parser = create_parser("Run the app for a long time and monitor it.")
    parser.add_argument(
        "-d",
        "--duration",
        type=float,
        default=8,
        help="Duration in hours (default: %(default)s).",
    )
    parser.add_argument(
        "--ingests",
        type=parse_ingests,
        default=list(Ingest),
        help="Comma separated list of ingests to stream to, for example 'rtmp,whep'.\n\n"
        "Give an empty list to disable all ingests (default: all).",
    )
    parser.add_argument(
        "-p",
        "--stream-protocol",
        type=parse_stream_protocol,
        choices=list(StreamProtocol),
        default=StreamProtocol.SRT,
        help="Outgoing stream protocol (default: %(default)s).",
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
    run("stability", parser, create_suites)


main()
