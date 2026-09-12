import random
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from systest_moblin.ffmpeg import ffmpeg_run

from ..utils.config import WEB_SERVER_PORT
from ..utils.generate_device_settings import EMPTY_SCENE_SETTINGS
from ..utils.generate_device_settings import FRONT_SCENE_SETTINGS
from ..utils.generate_device_settings import RECORD_STREAM_SETTINGS
from ..utils.generate_device_settings import SCREEN_SCENE_SETTINGS
from ..utils.generate_device_settings import Alignment
from ..utils.generate_device_settings import SceneName
from ..utils.generate_device_settings import chat_widget_settings
from ..utils.generate_device_settings import scene_widget_settings
from ..utils.generate_device_settings import uuid
from ..utils.http_server import HttpServer
from ..utils.moblin import Moblin
from ..utils.test_case import TestCase
from ..utils.utils import FILES_DIR

CHAT_WIDGET_ID = uuid()
NUMBER_OF_EMOTES = 100
MESSAGES_PER_SECOND = 10
NUMBER_OF_MESSAGES = 15 * MESSAGES_PER_SECOND
SPAM_EMOTES_PER_MESSAGE = 8
WORDS = ["hi", "chat", "lol", "wow", "gg", "nice", "moblin", "irl", "so", "many", "emotes"]
USERS = ["Alice", "Bob", "Carol", "Dave", "Erin"]


class ChatTestCase(TestCase):
    def setup(self):
        self.moblin.import_settings(
            overrides={
                "streams": [RECORD_STREAM_SETTINGS],
                "scenes": [EMPTY_SCENE_SETTINGS, SCREEN_SCENE_SETTINGS],
                "chat": {
                    "botEnabled": True,
                    "botCommandPermissions": {"scene": {"moderatorsEnabled": True}, "migrated": True},
                    "aliases": [{"alias": "!screen", "replacement": "!moblin scene Screen"}],
                },
            }
        )


class ChatBotSwitchScene(ChatTestCase):
    """Switch scenes by sending chat bot commands over the remote control."""

    def run(self):
        self.switch_scene(SceneName.SCREEN, "Screen capture")
        self.switch_scene(SceneName.EMPTY, "None")

    def switch_scene(self, name: SceneName, camera: str):
        self.moblin.send_chat_message(f"!moblin scene {name}")
        self.wait_until(lambda: self.moblin.get_camera_status() == camera)


class ChatBotSwitchSceneUsingAlias(ChatTestCase):
    """Switch scene by sending a chat bot command alias over the remote control."""

    def run(self):
        self.wait_until(lambda: self.moblin.get_camera_status() != "Screen capture")
        self.moblin.send_chat_message("!screen")
        self.wait_until(lambda: self.moblin.get_camera_status() == "Screen capture")


class ChatBotMuteAndUnmute(ChatTestCase):
    """Mute and unmute the audio by sending chat bot commands over the remote control."""

    def run(self):
        self.moblin.send_chat_message("!moblin mute")
        self.wait_until(self.moblin.is_muted)
        self.moblin.send_chat_message("!moblin unmute")
        self.wait_until(lambda: not self.moblin.is_muted())

    def teardown(self):
        self.moblin.set_muted(False)
        super().teardown()


class ChatBotNotAllowedToSwitchScene(ChatTestCase):
    """Do not switch scene when a chat bot command is sent by a user without permission."""

    def run(self):
        self.moblin.send_chat_message("!moblin scene Screen", is_moderator=False)
        self.moblin.send_chat_message("!moblin mute")
        self.wait_until(self.moblin.is_muted)
        self.assert_equal(self.moblin.get_camera_status(), "None")

    def teardown(self):
        self.moblin.set_muted(False)
        super().teardown()


def is_animated_emote(index: int) -> bool:
    return index % 2 == 0


def emote_file_name(index: int) -> str:
    return f"emote-{index:03}.{'gif' if is_animated_emote(index) else 'png'}"


def create_emote(static_root: Path, index: int):
    red, green, blue = (index * 37) % 256, (index * 91) % 256, (index * 143) % 256
    background = f"0x{red:02x}{green:02x}{blue:02x}"
    foreground = f"0x{255 - red:02x}{255 - green:02x}{255 - blue:02x}"
    path = static_root / emote_file_name(index)
    if is_animated_emote(index):
        ffmpeg_run(
            "-f",
            "lavfi",
            "-i",
            f"color=c={background}:s=48x48:r=10:d=1",
            "-f",
            "lavfi",
            "-i",
            f"color=c={foreground}:s=16x16:r=10:d=1",
            "-filter_complex",
            "overlay=x='(W-w)*t':y=16",
            str(path),
        )
    else:
        ffmpeg_run(
            "-f",
            "lavfi",
            "-i",
            f"color=c={background}:s=48x48:d=1",
            "-vf",
            f"drawbox=x=8:y=8:w=32:h=32:color={foreground}:t=fill",
            "-frames:v",
            "1",
            "-update",
            "1",
            str(path),
        )


def create_emotes() -> Path:
    static_root = FILES_DIR / "emotes"
    static_root.mkdir(exist_ok=True)
    with ThreadPoolExecutor(max_workers=8) as executor:
        futures = [executor.submit(create_emote, static_root, index) for index in range(NUMBER_OF_EMOTES)]
        for future in futures:
            future.result()
    return static_root


def take_emote_index(random_generator: random.Random, unused: list[int]) -> int:
    if unused:
        return unused.pop()
    return random_generator.randrange(NUMBER_OF_EMOTES)


def pick_emote_indexes(random_generator: random.Random, unused: list[int], index: int) -> list[int]:
    if index % 5 == 4:
        return [take_emote_index(random_generator, unused)] * SPAM_EMOTES_PER_MESSAGE
    return [take_emote_index(random_generator, unused) for _ in range(random_generator.randint(1, 3))]


def create_segments(
    random_generator: random.Random,
    emote_urls: list[str],
    emote_indexes: list[int],
) -> list[dict]:
    segments: list[dict] = []
    for position, emote_index in enumerate(emote_indexes):
        if position == 0 or random_generator.random() < 0.3:
            segments.append({"id": len(segments), "text": f"{random_generator.choice(WORDS)} "})
        key = "moving" if is_animated_emote(emote_index) else "still"
        segments.append({"id": len(segments), "url": {key: emote_urls[emote_index]}})
    return segments


class ChatEmotes(TestCase):
    """Send 100 animated and still emotes in 10 chat messages per second for 15 seconds."""

    def setup(self):
        self.moblin.import_settings(
            overrides={
                "scenes": [
                    {
                        **FRONT_SCENE_SETTINGS,
                        "widgets": [scene_widget_settings(CHAT_WIDGET_ID, 0, 0, 100, Alignment.TOP_RIGHT)],
                    }
                ],
                "widgets": [chat_widget_settings("Chat", CHAT_WIDGET_ID, 30)],
            }
        )

    def run(self):
        static_root = create_emotes()
        with HttpServer(WEB_SERVER_PORT, static_root, self.moblin.config.tester_ip_address()) as server:
            run_id = uuid()
            emote_urls = [
                server.url(f"/{emote_file_name(index)}?{run_id}") for index in range(NUMBER_OF_EMOTES)
            ]
            self.send_messages(emote_urls)
            self.wait_until(lambda: len(server.request_counts()) == NUMBER_OF_EMOTES)
            self.assert_fetched_once(server.request_counts())

    def send_messages(self, emote_urls: list[str]):
        random_generator = random.Random(1)
        unused = list(range(NUMBER_OF_EMOTES))
        random_generator.shuffle(unused)
        started = time.monotonic()
        for index in range(NUMBER_OF_MESSAGES):
            emote_indexes = pick_emote_indexes(random_generator, unused, index)
            self.moblin.send_chat_message(
                "",
                is_moderator=False,
                display_name=random_generator.choice(USERS),
                segments=create_segments(random_generator, emote_urls, emote_indexes),
            )
            deadline = started + (index + 1) / MESSAGES_PER_SECOND
            time.sleep(max(deadline - time.monotonic(), 0))
        self.assert_equal(unused, [], "Not all emotes were sent.")

    def assert_fetched_once(self, request_counts: dict[str, int]):
        for index in range(NUMBER_OF_EMOTES):
            path = f"/{emote_file_name(index)}"
            self.assert_equal(request_counts.get(path, 0), 1, path)
        self.assert_equal(len(request_counts), NUMBER_OF_EMOTES)


def tests(moblin: Moblin):
    return [
        ChatBotSwitchScene(moblin),
        ChatBotSwitchSceneUsingAlias(moblin),
        ChatBotMuteAndUnmute(moblin),
        ChatBotNotAllowedToSwitchScene(moblin),
        ChatEmotes(moblin),
    ]
