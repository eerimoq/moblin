from suites import stability

from utils.runner import create_parser
from utils.runner import run


def main():
    parser = create_parser("Run the app for a long time and monitor it.")
    parser.add_argument(
        "--duration",
        type=float,
        default=stability.DEFAULT_DURATION / 3600,
        help="Duration in hours (default: %(default)s).",
    )
    run(
        "stability",
        parser,
        lambda moblin, args: [stability.tests(moblin, 3600 * args.duration)],
    )


main()
