import logging
import time

from systest import wait_until

from ..utils.config import Capability
from ..utils.moblin import Moblin
from ..utils.test_case import TestCase
from ..utils.utils import manual_confirmation
from ..utils.utils import manual_requirement
from ..utils.utils import manual_validation
from ..utils.utils import manual_volume_requirement

LOGGER = logging.getLogger(__name__)
ADD_SONG = "Rick Astley Never Gonna Give You Up"
PAUSE_SONG = "Toto Africa"
NEXT_SONG = "Daft Punk Get Lucky"
PREVIOUS_SONG = "Queen Bohemian Rhapsody"
NOT_ALLOWED_SONG = "ABBA Dancing Queen"
COMMAND_DELAY = 5
QUICK_ADD_SONGS = [
    "https://music.apple.com/us/album/billie-jean/269572838?i=269573364",
    "https://music.apple.com/us/album/take-on-me/380907762?i=380907765",
    "https://music.apple.com/us/album/eye-of-the-tiger/254685010?i=254685026",
    "https://music.apple.com/us/album/the-final-countdown/196480323?i=196480329",
    "https://music.apple.com/us/album/livin-on-a-prayer/1422954626?i=1422955211",
    "https://music.apple.com/us/album/dont-stop-believin-2024-remaster/169003304?i=169003415",
]


class MusicTestCase(TestCase):
    def setup(self):
        self.skip_if_missing_capability(Capability.APPLE_MUSIC)
        manual_volume_requirement(LOGGER)
        manual_requirement(LOGGER, "Allow Moblin to access Apple Music")
        self.moblin.import_settings(
            overrides={
                "chat": {
                    "botEnabled": True,
                    "botCommandPermissions": {"music": {"moderatorsEnabled": True}, "migrated": True},
                }
            }
        )
        self.moblin.send_chat_message("!moblin music clear")

    def teardown(self):
        self.moblin.send_chat_message("!moblin music clear")
        super().teardown()

    def send(self, *commands: str, is_moderator: bool = True):
        for command in commands:
            if self.moblin.is_interactive():
                manual_confirmation(f"Get ready to validate '{command}'.")
            self.moblin.send_chat_message(f"!moblin music {command}", is_moderator=is_moderator)
            if not self.moblin.is_interactive():
                time.sleep(COMMAND_DELAY)


class MusicAddAndPlay(MusicTestCase):
    """Add a song and play it by sending chat bot commands."""

    def run(self):
        manual_validation(LOGGER, f"{ADD_SONG} is heard from the speaker.")
        self.send(f"add {ADD_SONG}", "play")


class MusicPauseAndPlay(MusicTestCase):
    """Pause and resume the music by sending chat bot commands."""

    def run(self):
        manual_validation(LOGGER, f"{PAUSE_SONG} is heard, paused and then resumed.")
        self.send(f"add {PAUSE_SONG}", "pause", "play")


class MusicNextAndPrevious(MusicTestCase):
    """Skip to the next and previous song by sending chat bot commands."""

    def run(self):
        manual_validation(
            LOGGER,
            f"{NEXT_SONG} is heard, then {PREVIOUS_SONG} after next and {NEXT_SONG} again after previous.",
        )
        self.send(f"add {NEXT_SONG}", f"add {PREVIOUS_SONG}", "next", "previous")


class MusicNotAllowed(MusicTestCase):
    """Do not control the music when the chat bot command is sent by a user without permission."""

    def run(self):
        manual_validation(
            LOGGER,
            f"{NOT_ALLOWED_SONG} is heard, paused, stays paused after the first play and then resumes.",
        )
        self.send(f"add {NOT_ALLOWED_SONG}", "pause")
        self.send("play", is_moderator=False)
        self.send("play")


class MusicAddManySongsQuickly(MusicTestCase):
    """Add many songs in quick succession while a song is playing by sending chat bot commands."""

    def run(self):
        self.send(f"add {ADD_SONG}")
        for song in QUICK_ADD_SONGS:
            self.moblin.send_chat_message(f"!moblin music add {song}")
        wait_until(
            lambda: len(self.moblin.get_music_status()["songs"]) == len(QUICK_ADD_SONGS) + 1,
            "all songs to be added",
        )
        self.assert_true(self.moblin.get_music_status()["playing"], "music is playing")


def tests(moblin: Moblin):
    return [
        MusicAddAndPlay(moblin),
        MusicPauseAndPlay(moblin),
        MusicNextAndPrevious(moblin),
        MusicNotAllowed(moblin),
        MusicAddManySongsQuickly(moblin),
    ]
