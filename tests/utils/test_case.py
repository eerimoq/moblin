import logging
import re
import time

import systest
from systest_moblin import test_case

from .config import Capability
from .moblin import Moblin
from .utils import Range

LOGGER = logging.getLogger(__name__)
RE_LTCDUMP = re.compile(r"\S+\s+00:(\d+):(\d+):.*")
CHANNEL_LAYOUTS = {1: "mono", 2: "stereo"}
AUDIO_SAMPLES_PER_FRAME = 1024


class TestCase(test_case.TestCase):
    def __init__(self, moblin: Moblin, name: str | None = None):
        super().__init__(name)
        self.moblin = moblin

    def teardown(self):
        self.moblin.end()
        self.moblin.stop_recording()
        self.moving_picture_off()

    def skip_if_missing_capability(self, capability: Capability):
        if not self.moblin.has_capability(capability):
            raise systest.TestCaseSkippedError(f"{capability} capability missing.")

    def skip_if_no_secondary_ip_address(self):
        if not self.moblin.has_secondary_ip_address():
            raise systest.TestCaseSkippedError("No secondary IP address.")

    def skip_if_no_receiver(self):
        if not self.moblin.config.has_receiver():
            raise systest.TestCaseSkippedError("No receiver.")

    def skip_if_no_moving_picture(self):
        if not self.moblin.has_moving_picture():
            raise systest.TestCaseSkippedError("No moving picture.")

    def skip_if_no_dji_camera(self):
        if not self.moblin.has_dji_camera():
            raise systest.TestCaseSkippedError("No DJI camera.")

    def skip_if_not_interactive(self):
        if not self.moblin.is_interactive():
            raise systest.TestCaseSkippedError("Not interactive.")

    def moving_picture_on(self):
        if self.moblin.arduino is None:
            return
        self.moblin.arduino.back_motor_on()
        self.moblin.arduino.front_motor_on()

    def moving_picture_off(self):
        if self.moblin.arduino is None:
            return
        self.moblin.arduino.back_motor_off()
        self.moblin.arduino.front_motor_off()

    def wait_for_ingest_stream_started(self, number_of_ingests=1, startup_delay=1):
        time.sleep(startup_delay)
        self.moblin.wait_for_ingests(
            bitrate=Range(0, 100_000_000),
            total_bytes=3_000_000,
            number_of_ingests=number_of_ingests,
        )
