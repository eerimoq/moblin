import systest

from .moblin import Moblin


class TestCase(systest.TestCase):
    def __init__(self, moblin: Moblin):
        super().__init__()
        self.moblin = moblin
