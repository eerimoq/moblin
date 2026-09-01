from ..utils.generate_device_settings import EMPTY_SCENE_SETTINGS
from ..utils.generate_device_settings import RECORD_STREAM_SETTINGS
from ..utils.generate_device_settings import SCREEN_SCENE_SETTINGS
from ..utils.generate_device_settings import SceneName
from ..utils.moblin import Moblin
from ..utils.test_case import TestCase


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


def tests(moblin: Moblin):
    return [
        ChatBotSwitchScene(moblin),
        ChatBotSwitchSceneUsingAlias(moblin),
        ChatBotMuteAndUnmute(moblin),
        ChatBotNotAllowedToSwitchScene(moblin),
    ]
