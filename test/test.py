import logging
import systest
from utils.moblin import Moblin
from utils.media_mtx import MediaMtx

LOGGER = logging.getLogger(__name__)


class RtmpFromMoblinToMediaMtx(systest.TestCase):
    def __init__(self, moblin: Moblin):
        super().__init__()
        self.moblin = moblin

    def run(self):
        with MediaMtx():
            self.moblin.go_live()


def main():
    sequencer = systest.setup("all")

    with Moblin() as moblin:
        sequencer.run(RtmpFromMoblinToMediaMtx(moblin))

    sequencer.report_and_exit()


main()
