import json
import logging

from websockets.sync.client import connect

from ..utils.config import WEB_REMOTE_CONTROL_PORT
from ..utils.generate_device_settings import SceneName
from ..utils.moblin import Moblin
from ..utils.test_case import TestCase
from ..utils.utils import manual_confirmation
from ..utils.utils import manual_validation

LOGGER = logging.getLogger(__name__)
RED = {"red": 255, "green": 0, "blue": 0}
DARK_BLUE = {"red": 0, "green": 0, "blue": 128}
YELLOW = {"red": 255, "green": 255, "blue": 0}
WHITE = {"red": 255, "green": 255, "blue": 255}
BLACK = {"red": 0, "green": 0, "blue": 0}


class WebRemoteControl:
    def __init__(self, moblin: Moblin):
        self._websocket = connect(f"ws://{moblin.ip_address}:{WEB_REMOTE_CONTROL_PORT + 1}", max_size=None)
        self._next_id = 0

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self._websocket.close()

    def show_tally(self, message: str, background: dict[str, int], foreground: dict[str, int]) -> dict:
        return self._request(
            {"showTally": {"message": message, "background": background, "foreground": foreground}}
        )

    def hide_tally(self) -> dict:
        return self._request({"hideTally": {}})

    def _request(self, data: dict) -> dict:
        self._next_id += 1
        self._websocket.send(json.dumps({"request": {"id": self._next_id, "data": data}}))
        while True:
            response = json.loads(self._websocket.recv(timeout=15)).get("response")
            if response is not None and response["id"] == self._next_id:
                return response["result"]


class TallyTestCase(TestCase):
    def setup(self):
        self.moblin.import_settings(overrides={})

    def teardown(self):
        self.moblin.hide_tally()
        super().teardown()

    def validate(self, message: str):
        manual_validation(LOGGER, message)
        if self.moblin.is_interactive():
            manual_confirmation("Validate the tally on the device.")


class TallyShowAndHide(TallyTestCase):
    """Show, update and hide the tally with different colors and messages."""

    def run(self):
        self.moblin.set_scene(SceneName.FRONT)
        self.assert_in("ok", self.moblin.show_tally("ON AIR", RED, WHITE))
        self.validate("A red border and white ON AIR text on red at the top are shown.")
        self.assert_in("ok", self.moblin.show_tally("PREVIEW", DARK_BLUE, YELLOW))
        self.validate("A dark blue border and yellow PREVIEW text on dark blue at the top are shown.")
        self.assert_in("ok", self.moblin.show_tally("", YELLOW, BLACK))
        self.validate("A yellow border without any text is shown.")
        self.assert_in("ok", self.moblin.hide_tally())
        self.validate("No border or text is shown.")


class TallyAssistantDisconnected(TallyTestCase):
    """Hide the tally when the assistant disconnects."""

    def run(self):
        self.moblin.set_scene(SceneName.FRONT)
        self.assert_in("ok", self.moblin.show_tally("ON AIR", RED, WHITE))
        self.validate("A red border and ON AIR text are shown.")
        self.moblin.restart_assistant()
        self.validate("No border or text is shown.")


class TallyWebRemoteControlDisconnected(TallyTestCase):
    """Hide the tally when any web remote control disconnects."""

    def run(self):
        self.moblin.set_scene(SceneName.FRONT)
        with WebRemoteControl(self.moblin) as first:
            with WebRemoteControl(self.moblin) as second:
                self.assert_in("ok", first.show_tally("ON AIR", RED, WHITE))
                self.assert_in("ok", second.hide_tally())
                self.validate("No border or text is shown.")
                self.assert_in("ok", first.show_tally("ON AIR", RED, WHITE))
                self.validate("A red border and ON AIR text are shown.")
            self.validate("No border or text is shown.")
            self.assert_in("ok", first.show_tally("ON AIR", RED, WHITE))
            self.validate("A red border and ON AIR text are shown.")
        self.validate("No border or text is shown.")


def tests(moblin: Moblin):
    return [
        TallyShowAndHide(moblin),
        TallyAssistantDisconnected(moblin),
        TallyWebRemoteControlDisconnected(moblin),
    ]
