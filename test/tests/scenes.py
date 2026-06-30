import systest
from utils.moblin import Moblin


class SceneSwitchMultipleTimes(systest.TestCase):
    """Switch between two scenes a few times."""

    def __init__(self, moblin: Moblin):
        super().__init__()
        self.moblin = moblin

    def run(self):
        for _ in range(10):
            self.moblin.set_scene("Screen")
            self.moblin.set_scene("Front")


def tests(moblin: Moblin):
    return [
        SceneSwitchMultipleTimes(moblin),
    ]
