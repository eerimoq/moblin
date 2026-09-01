import time

from ..utils.config import Capability
from ..utils.moblin import Moblin
from ..utils.test_case import TestCase

MOVEMENT_DURATION = 1
TRACKING_DURATION = 5
ANIMATION_DURATION = 5


class GimbalTestCase(TestCase):
    def setup(self):
        self.skip_if_missing_capability(Capability.GIMBAL)
        self.moblin.import_settings(overrides={})
        self.moblin.set_gimbal_tracking(False)
        self.moblin.wait_for_gimbal_tracking(False)

    def teardown(self):
        self.moblin.set_gimbal_movement(0, 0)
        self.moblin.set_gimbal_tracking(True)
        super().teardown()


class GimbalTracking(GimbalTestCase):
    """Turn gimbal tracking on and off."""

    def run(self):
        self.moblin.set_gimbal_tracking(True)
        self.moblin.wait_for_gimbal_tracking(True)
        time.sleep(TRACKING_DURATION)
        self.moblin.set_gimbal_tracking(False)
        self.moblin.wait_for_gimbal_tracking(False)
        time.sleep(TRACKING_DURATION)


class GimbalMovement(GimbalTestCase):
    """Move the gimbal up, down, left and right for one second each."""

    def run(self):
        for x, y in [(1, 0), (-1, 0), (0, 1), (0, -1)]:
            self.moblin.set_gimbal_movement(x, y)
            time.sleep(MOVEMENT_DURATION)
            self.moblin.set_gimbal_movement(0, 0)
            time.sleep(MOVEMENT_DURATION)


class GimbalPreset(GimbalTestCase):
    """Save a gimbal preset, move away from it and then back to it."""

    def run(self):
        self.moblin.save_gimbal_preset()
        presets = self.moblin.wait_for_gimbal_presets(1)
        self.moblin.set_gimbal_movement(1, 1)
        time.sleep(MOVEMENT_DURATION)
        self.moblin.set_gimbal_movement(0, 0)
        self.moblin.move_to_gimbal_preset(presets[0]["id"])


class GimbalAnimate(GimbalTestCase):
    """Play all gimbal animations."""

    def run(self):
        for motion in ["kapow", "yes", "no", "wakeup"]:
            self.moblin.animate_gimbal(motion)
            time.sleep(ANIMATION_DURATION)


def tests(moblin: Moblin):
    return [
        GimbalTracking(moblin),
        GimbalMovement(moblin),
        GimbalPreset(moblin),
        GimbalAnimate(moblin),
    ]
