from suites import browser_widget
from suites import ingests
from suites import record
from suites import scenes
from suites import stream
from suites import talkback
from suites import web_remote_control

from utils.runner import create_parser
from utils.runner import run


def main():
    run(
        "test",
        create_parser(),
        lambda moblin, _: [
            talkback.tests(moblin),
            ingests.tests(moblin),
            record.tests(moblin),
            scenes.tests(moblin),
            stream.tests(moblin),
            browser_widget.tests(moblin),
            web_remote_control.tests(moblin),
        ],
    )


main()
