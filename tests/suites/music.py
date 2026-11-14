import logging
import threading
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

    def add_songs_quickly(self, songs: list[str]):
        for song in songs:
            self.moblin.send_chat_message(f"!moblin music add {song}")

    def wait_for_number_of_songs(self, number_of_songs: int) -> dict:
        wait_until(
            lambda: len(self.moblin.get_music_status()["songs"]) == number_of_songs,
            f"{number_of_songs} songs in the queue",
        )
        return self.moblin.get_music_status()

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
        for song in 3 * QUICK_ADD_SONGS:
            self.moblin.send_chat_message(f"!moblin music add {song}")
        wait_until(
            lambda: len(self.moblin.get_music_status()["songs"]) == 3 * len(QUICK_ADD_SONGS) + 1,
            "all songs to be added",
        )
        self.assert_true(self.moblin.get_music_status()["playing"], "music is playing")


class MusicRemoveSongsQuickly(MusicTestCase):
    """Remove songs in quick succession right after adding them and then add another song."""

    def run(self):
        self.send(f"add {ADD_SONG}")
        self.add_songs_quickly(QUICK_ADD_SONGS)
        status = self.wait_for_number_of_songs(len(QUICK_ADD_SONGS) + 1)
        removed_ids = [song["id"] for song in status["songs"][-3:]]
        for entry_id in removed_ids:
            self.moblin.remove_music(entry_id)
        self.add_songs_quickly(QUICK_ADD_SONGS[:1])
        status = self.wait_for_number_of_songs(len(QUICK_ADD_SONGS) - 1)
        self.assert_equal([song["id"] for song in status["songs"] if song["id"] in removed_ids], [])
        self.assert_true(status["playing"], "music is playing")


class MusicRemoveCurrentSongRightAfterAdd(MusicTestCase):
    """Remove the playing song right after adding a song."""

    def run(self):
        self.send(f"add {ADD_SONG}")
        status = self.moblin.get_music_status()
        current_id = status["songs"][status["currentSongIndex"]]["id"]
        adder = threading.Thread(target=self.moblin.add_music, args=(QUICK_ADD_SONGS[0],))
        adder.start()
        time.sleep(0.01)
        self.moblin.remove_music(current_id)
        adder.join()
        status = self.wait_for_number_of_songs(1)
        self.assert_not_equal(status["songs"][0]["id"], current_id)
        wait_until(lambda: self.moblin.get_music_status()["playing"], "music to play")


class MusicSelectSongsQuickly(MusicTestCase):
    """Select the last song right after adding songs and then add another song."""

    def run(self):
        self.send(f"add {ADD_SONG}")
        self.add_songs_quickly(QUICK_ADD_SONGS)
        status = self.wait_for_number_of_songs(len(QUICK_ADD_SONGS) + 1)
        self.moblin.select_music(status["songs"][-1]["id"])
        self.add_songs_quickly(QUICK_ADD_SONGS[:1])
        status = self.wait_for_number_of_songs(len(QUICK_ADD_SONGS) + 2)
        self.assert_equal(status["currentSongIndex"], len(QUICK_ADD_SONGS))
        self.assert_true(status["playing"], "music is playing")


def tests(moblin: Moblin):
    return [
        MusicAddAndPlay(moblin),
        MusicPauseAndPlay(moblin),
        MusicNextAndPrevious(moblin),
        MusicNotAllowed(moblin),
        MusicAddManySongsQuickly(moblin),
        MusicRemoveSongsQuickly(moblin),
        MusicRemoveCurrentSongRightAfterAdd(moblin),
        MusicSelectSongsQuickly(moblin),
    ]
