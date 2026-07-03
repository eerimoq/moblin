from utils.moblin import Moblin
from utils.test_case import TestCase


class SceneSwitchMultipleTimes(TestCase):
    """Switch between two scenes a few times."""

    def run(self):
        for _ in range(10):
            self.moblin.set_scene("Screen")
            self.moblin.set_scene("Front")


class ScenePiPBackFront(TestCase):
    """A picture in picture scene with full screen back camera and small front camera in
    bottom right. Record for a few seconds and validate the recording.

    """

    def run(self):
        pass


def tests(moblin: Moblin):
    return [
        SceneSwitchMultipleTimes(moblin),
    ]
