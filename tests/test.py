from suites import browser_widget
from suites import chat
from suites import ingests
from suites import record
from suites import scenes
from suites import stream
from suites import talkback
from suites import web_remote_control

from utils.runner import create_parser
from utils.runner import run


def create_suites(moblin, _):
    return [
        talkback.tests(moblin),
        ingests.tests(moblin),
        record.tests(moblin),
        scenes.tests(moblin),
        stream.tests(moblin),
        browser_widget.tests(moblin),
        chat.tests(moblin),
        web_remote_control.tests(moblin),
    ]


def main():
    parser = create_parser("Run tests.")
    parser.add_argument("--moving-picture", action="store_true")
    parser.add_argument("--arduino-serial-port")
    parser.add_argument(
        "--skip-background-streaming",
        action="store_true",
        help="Skip all tests that requires background streaming.",
    )
    run("test", parser, create_suites)


main()
