from .suites import browser_widget
from .suites import chat
from .suites import dji_camera
from .suites import ingests
from .suites import mic_delay
from .suites import mic_switch
from .suites import record
from .suites import scenes
from .suites import stream
from .suites import talkback
from .suites import web_remote_control
from .utils.runner import create_parser
from .utils.runner import run


def create_suites(moblin, _):
    return [
        talkback.tests(moblin),
        ingests.tests(moblin),
        record.tests(moblin),
        mic_delay.tests(moblin),
        mic_switch.tests(moblin),
        scenes.tests(moblin),
        stream.tests(moblin),
        browser_widget.tests(moblin),
        chat.tests(moblin),
        dji_camera.tests(moblin),
        web_remote_control.tests(moblin),
    ]


def main():
    parser = create_parser("Run tests.")
    run("test", parser, create_suites)


main()
