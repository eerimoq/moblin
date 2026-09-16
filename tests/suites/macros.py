import time

from ..utils.generate_device_settings import EMPTY_SCENE_SETTINGS
from ..utils.generate_device_settings import SCREEN_SCENE_SETTINGS
from ..utils.generate_device_settings import MacroIfComparison
from ..utils.generate_device_settings import MacroRepeatMode
from ..utils.generate_device_settings import SceneName
from ..utils.generate_device_settings import macro_delay_action
from ..utils.generate_device_settings import macro_if_action
from ..utils.generate_device_settings import macro_mute_action
from ..utils.generate_device_settings import macro_run_macro_action
from ..utils.generate_device_settings import macro_scene_action
from ..utils.generate_device_settings import macro_settings
from ..utils.generate_device_settings import uuid
from ..utils.moblin import Moblin
from ..utils.test_case import TestCase

MUTED = "🔇"
DELAY = 2
MACRO_ID = uuid()
OTHER_MACRO_ID = uuid()


class MacroTestCase(TestCase):
    def __init__(self, moblin: Moblin, name: str | None = None):
        super().__init__(moblin, name)
        self.empty_scene_id = uuid()
        self.screen_scene_id = uuid()
        self.macro_ids: list[str] = []

    def teardown(self):
        for macro_id in self.macro_ids:
            self.moblin.stop_macro(macro_id)
        self.moblin.set_muted(False)
        super().teardown()

    def import_settings(self, macros: list[dict], chat: dict | None = None):
        overrides = {"scenes": self.scenes_settings(), "macros": {"macros": macros}}
        if chat is not None:
            overrides["chat"] = chat
        self.moblin.import_settings(overrides=overrides)
        self.macro_ids = [macro["id"] for macro in macros]
        self.moblin.set_scene(SceneName.EMPTY)
        self.moblin.wait_for_scene(self.empty_scene_id)

    def scenes_settings(self) -> list[dict]:
        return [
            {**EMPTY_SCENE_SETTINGS, "id": self.empty_scene_id},
            {**SCREEN_SCENE_SETTINGS, "id": self.screen_scene_id},
        ]

    def scene_cycle_actions(self) -> list[dict]:
        return [
            macro_scene_action(self.screen_scene_id),
            macro_delay_action(DELAY),
            macro_scene_action(self.empty_scene_id),
            macro_delay_action(DELAY),
        ]

    def wait_for_scene_cycles(self, count: int):
        for _ in range(count):
            self.moblin.wait_for_scene(self.screen_scene_id)
            self.moblin.wait_for_scene(self.empty_scene_id)

    def wait_for_muted(self, muted: bool):
        self.wait_until(lambda: self.moblin.is_muted() == muted)

    def assert_scene_unchanged(self, scene_id: str, seconds: float = 2 * DELAY + 1):
        end_time = time.monotonic() + seconds
        while time.monotonic() < end_time:
            self.assert_equal(self.moblin.get_scene(), scene_id)
            time.sleep(0.5)

    def assert_muted_unchanged(self, muted: bool, seconds: float = 2 * DELAY + 1):
        end_time = time.monotonic() + seconds
        while time.monotonic() < end_time:
            self.assert_equal(self.moblin.is_muted(), muted)
            time.sleep(0.5)


class MacroSwitchScenes(MacroTestCase):
    """Run a macro that switches scene, delays and switches back."""

    def setup(self):
        self.import_settings(
            [
                macro_settings(
                    MACRO_ID,
                    "Scenes",
                    [
                        macro_scene_action(self.screen_scene_id),
                        macro_delay_action(DELAY),
                        macro_scene_action(self.empty_scene_id),
                    ],
                )
            ]
        )

    def run(self):
        self.moblin.start_macro(MACRO_ID)
        self.moblin.wait_for_scene(self.screen_scene_id)
        self.moblin.wait_for_macro_running(MACRO_ID, True)
        self.moblin.wait_for_scene(self.empty_scene_id)
        self.moblin.wait_for_macro_running(MACRO_ID, False)
        self.assert_scene_unchanged(self.empty_scene_id)


class MacroMuteAndUnmute(MacroTestCase):
    """Run a macro that mutes, delays and unmutes."""

    def setup(self):
        self.import_settings(
            [
                macro_settings(
                    MACRO_ID,
                    "Mute",
                    [macro_mute_action(True), macro_delay_action(DELAY), macro_mute_action(False)],
                )
            ]
        )

    def run(self):
        self.wait_for_muted(False)
        self.moblin.start_macro(MACRO_ID)
        self.wait_for_muted(True)
        self.moblin.wait_for_macro_running(MACRO_ID, True)
        self.wait_for_muted(False)
        self.moblin.wait_for_macro_running(MACRO_ID, False)


class MacroRepeatCount(MacroTestCase):
    """Run a scene switching macro three times and validate that it then stops."""

    def setup(self):
        self.import_settings(
            [
                macro_settings(
                    MACRO_ID,
                    "Repeat",
                    self.scene_cycle_actions(),
                    repeat_mode=MacroRepeatMode.COUNT,
                    repeat_count=3,
                )
            ]
        )

    def run(self):
        self.moblin.start_macro(MACRO_ID)
        self.wait_for_scene_cycles(3)
        self.moblin.wait_for_macro_running(MACRO_ID, False)
        self.assert_scene_unchanged(self.empty_scene_id)


class MacroRepeatForeverStop(MacroTestCase):
    """Run a scene switching macro forever, stop it and validate that it stops switching
    scenes.

    """

    def setup(self):
        self.import_settings(
            [
                macro_settings(
                    MACRO_ID,
                    "Forever",
                    self.scene_cycle_actions(),
                    repeat_mode=MacroRepeatMode.FOREVER,
                )
            ]
        )

    def run(self):
        self.moblin.start_macro(MACRO_ID)
        self.wait_for_scene_cycles(2)
        self.assert_true(self.moblin.is_macro_running(MACRO_ID), "Macro not running")
        self.moblin.stop_macro(MACRO_ID)
        self.moblin.wait_for_macro_running(MACRO_ID, False)
        self.assert_scene_unchanged(self.moblin.get_scene())


class MacroNoActions(MacroTestCase):
    """Run a macro without actions and validate that it finishes immediately."""

    def setup(self):
        self.import_settings([macro_settings(MACRO_ID, "Empty", [])])

    def run(self):
        self.moblin.start_macro(MACRO_ID)
        self.assert_scene_unchanged(self.empty_scene_id, seconds=2)
        self.assert_false(self.moblin.is_macro_running(MACRO_ID), "Macro still running")


class MacroNoActionsRepeatForever(MacroTestCase):
    """Run a macro without actions forever. Validate that the app stays responsive, that
    the macro can be stopped and that another macro runs afterwards.

    """

    def setup(self):
        self.import_settings(
            [
                macro_settings(MACRO_ID, "Empty", [], repeat_mode=MacroRepeatMode.FOREVER),
                macro_settings(
                    OTHER_MACRO_ID,
                    "Scene",
                    [macro_scene_action(self.screen_scene_id)],
                ),
            ]
        )

    def run(self):
        self.moblin.start_macro(MACRO_ID)
        self.moblin.wait_for_macro_running(MACRO_ID, True)
        self.assert_scene_unchanged(self.empty_scene_id)
        self.moblin.ping()
        self.assert_true(self.moblin.is_macro_running(MACRO_ID), "Macro not running")
        self.moblin.stop_macro(MACRO_ID)
        self.moblin.wait_for_macro_running(MACRO_ID, False)
        self.moblin.start_macro(OTHER_MACRO_ID)
        self.moblin.wait_for_scene(self.screen_scene_id)
        self.moblin.wait_for_macro_running(OTHER_MACRO_ID, False)


class MacroRunsItself(MacroTestCase):
    """Run a macro that runs itself and validate that it does not recurse forever."""

    def setup(self):
        self.import_settings(
            [
                macro_settings(
                    MACRO_ID,
                    "Recursive",
                    [
                        macro_scene_action(self.screen_scene_id),
                        macro_delay_action(DELAY),
                        macro_run_macro_action(MACRO_ID),
                        macro_scene_action(self.empty_scene_id),
                    ],
                )
            ]
        )

    def run(self):
        self.moblin.start_macro(MACRO_ID)
        self.moblin.wait_for_scene(self.screen_scene_id)
        self.moblin.wait_for_scene(self.empty_scene_id)
        self.moblin.wait_for_macro_running(MACRO_ID, False)
        self.assert_scene_unchanged(self.empty_scene_id)


class MacroMutualRecursion(MacroTestCase):
    """Run a macro that runs another macro that runs the first macro. Validate that both
    macros run once and then stop.

    """

    def setup(self):
        self.import_settings(
            [
                macro_settings(
                    MACRO_ID,
                    "A",
                    [
                        macro_scene_action(self.screen_scene_id),
                        macro_delay_action(DELAY),
                        macro_run_macro_action(OTHER_MACRO_ID),
                    ],
                ),
                macro_settings(
                    OTHER_MACRO_ID,
                    "B",
                    [
                        macro_mute_action(True),
                        macro_delay_action(DELAY),
                        macro_run_macro_action(MACRO_ID),
                        macro_scene_action(self.empty_scene_id),
                    ],
                ),
            ]
        )

    def run(self):
        self.wait_for_muted(False)
        self.moblin.start_macro(MACRO_ID)
        self.moblin.wait_for_scene(self.screen_scene_id)
        self.wait_for_muted(True)
        self.moblin.wait_for_scene(self.empty_scene_id)
        self.moblin.wait_for_macro_running(MACRO_ID, False)
        self.assert_false(self.moblin.is_macro_running(OTHER_MACRO_ID), "Sub macro running")
        self.assert_scene_unchanged(self.empty_scene_id)
        self.assert_true(self.moblin.is_muted(), "Not muted")


class MacroIfConditions(MacroTestCase):
    """Run a macro with if conditions comparing numbers and strings. Validate that only
    the actions following true conditions run.

    """

    def setup(self):
        self.import_settings(
            [
                macro_settings(
                    MACRO_ID,
                    "If",
                    [
                        macro_if_action("10", MacroIfComparison.GREATER_THAN, "9"),
                        macro_scene_action(self.screen_scene_id),
                        macro_if_action("abc", MacroIfComparison.CONTAINS, "z"),
                        macro_scene_action(self.empty_scene_id),
                        macro_if_action("Alice", MacroIfComparison.EQUAL, "alice"),
                        macro_mute_action(True),
                        macro_if_action("2", MacroIfComparison.GREATER_EQUAL, "2.5"),
                        macro_mute_action(False),
                        macro_if_action("1", MacroIfComparison.NOT_EQUAL, "1", run_count=2),
                        macro_scene_action(self.empty_scene_id),
                        macro_mute_action(False),
                        macro_delay_action(DELAY),
                    ],
                )
            ]
        )

    def run(self):
        self.wait_for_muted(False)
        self.moblin.start_macro(MACRO_ID)
        self.moblin.wait_for_scene(self.screen_scene_id)
        self.wait_for_muted(True)
        self.moblin.wait_for_macro_running(MACRO_ID, False)
        self.assert_scene_unchanged(self.screen_scene_id, seconds=2)
        self.assert_true(self.moblin.is_muted(), "Not muted")


class MacroIfMutedVariable(MacroTestCase):
    """Run a macro with if conditions on the muted variable, which is changed by the macro
    itself. Validate that the conditions are evaluated when reached.

    """

    def setup(self):
        self.import_settings(
            [
                macro_settings(
                    MACRO_ID,
                    "If muted",
                    [
                        macro_mute_action(True),
                        macro_if_action("{muted}", MacroIfComparison.EQUAL, MUTED),
                        macro_scene_action(self.screen_scene_id),
                        macro_delay_action(DELAY),
                        macro_mute_action(False),
                        macro_if_action("{muted}", MacroIfComparison.EQUAL, MUTED),
                        macro_scene_action(self.empty_scene_id),
                    ],
                )
            ]
        )

    def run(self):
        self.wait_for_muted(False)
        self.moblin.start_macro(MACRO_ID)
        self.moblin.wait_for_scene(self.screen_scene_id)
        self.wait_for_muted(True)
        self.wait_for_muted(False)
        self.moblin.wait_for_macro_running(MACRO_ID, False)
        self.assert_scene_unchanged(self.screen_scene_id, seconds=2)


class MacroIfSkipsPastEnd(MacroTestCase):
    """Run a macro three times where a false if condition skips more actions than the
    macro has. Validate that the macro repeats and finishes cleanly.

    """

    def setup(self):
        self.import_settings(
            [
                macro_settings(
                    MACRO_ID,
                    "Skip",
                    [
                        macro_scene_action(self.screen_scene_id),
                        macro_delay_action(DELAY),
                        macro_if_action("1", MacroIfComparison.EQUAL, "2", run_count=100),
                        macro_scene_action(self.empty_scene_id),
                    ],
                    repeat_mode=MacroRepeatMode.COUNT,
                    repeat_count=3,
                )
            ]
        )

    def run(self):
        self.moblin.start_macro(MACRO_ID)
        self.moblin.wait_for_scene(self.screen_scene_id)
        self.moblin.wait_for_macro_running(MACRO_ID, True)
        self.moblin.wait_for_macro_running(MACRO_ID, False)
        self.assert_scene_unchanged(self.screen_scene_id, seconds=2)


class MacroSubMacroRepeatForever(MacroTestCase):
    """Run a macro that runs a sub macro that repeats forever. Validate that the parent
    macro never continues past the sub macro and that stopping the parent macro stops
    the sub macro.

    """

    def setup(self):
        self.import_settings(
            [
                macro_settings(
                    MACRO_ID,
                    "Parent",
                    [
                        macro_scene_action(self.screen_scene_id),
                        macro_run_macro_action(OTHER_MACRO_ID),
                        macro_scene_action(self.empty_scene_id),
                    ],
                ),
                macro_settings(
                    OTHER_MACRO_ID,
                    "Child",
                    [
                        macro_mute_action(True),
                        macro_delay_action(DELAY),
                        macro_mute_action(False),
                        macro_delay_action(DELAY),
                    ],
                    repeat_mode=MacroRepeatMode.FOREVER,
                ),
            ]
        )

    def run(self):
        self.wait_for_muted(False)
        self.moblin.start_macro(MACRO_ID)
        self.moblin.wait_for_scene(self.screen_scene_id)
        for _ in range(2):
            self.wait_for_muted(True)
            self.wait_for_muted(False)
        self.assert_true(self.moblin.is_macro_running(MACRO_ID), "Parent macro not running")
        self.assert_equal(self.moblin.get_scene(), self.screen_scene_id)
        self.moblin.stop_macro(MACRO_ID)
        self.moblin.wait_for_macro_running(MACRO_ID, False)
        self.assert_muted_unchanged(self.moblin.is_muted())
        self.assert_equal(self.moblin.get_scene(), self.screen_scene_id)


class MacroStopDuringDelayAndRestart(MacroTestCase):
    """Stop a macro while it is delaying. Validate that the actions after the delay never
    run and that the macro can be started again.

    """

    def setup(self):
        self.import_settings(
            [
                macro_settings(
                    MACRO_ID,
                    "Delayed",
                    [
                        macro_scene_action(self.screen_scene_id),
                        macro_delay_action(2 * DELAY),
                        macro_scene_action(self.empty_scene_id),
                    ],
                )
            ]
        )

    def run(self):
        self.moblin.start_macro(MACRO_ID)
        self.moblin.wait_for_scene(self.screen_scene_id)
        self.moblin.wait_for_macro_running(MACRO_ID, True)
        self.moblin.stop_macro(MACRO_ID)
        self.moblin.wait_for_macro_running(MACRO_ID, False)
        self.assert_scene_unchanged(self.screen_scene_id)
        self.moblin.start_macro(MACRO_ID)
        self.moblin.wait_for_macro_running(MACRO_ID, True)
        self.moblin.wait_for_scene(self.empty_scene_id)
        self.moblin.wait_for_macro_running(MACRO_ID, False)


class MacroChatBotRunAndCancel(MacroTestCase):
    """Run and cancel a macro with chat bot commands. Validate that a user without
    permission cannot run it.

    """

    def setup(self):
        self.import_settings(
            [
                macro_settings(
                    MACRO_ID,
                    "Loop",
                    self.scene_cycle_actions(),
                    repeat_mode=MacroRepeatMode.FOREVER,
                )
            ],
            chat={
                "botEnabled": True,
                "botCommandPermissions": {"macro": {"moderatorsEnabled": True}, "migrated": True},
            },
        )

    def run(self):
        self.moblin.send_chat_message("!moblin macro run loop", is_moderator=False)
        self.assert_scene_unchanged(self.empty_scene_id, seconds=2)
        self.assert_false(self.moblin.is_macro_running(MACRO_ID), "Macro running")
        self.moblin.send_chat_message("!moblin macro run loop")
        self.moblin.wait_for_macro_running(MACRO_ID, True)
        self.wait_for_scene_cycles(2)
        self.moblin.send_chat_message("!moblin macro cancel loop")
        self.moblin.wait_for_macro_running(MACRO_ID, False)
        self.assert_scene_unchanged(self.moblin.get_scene())


class MacroImportSettingsWhileRunning(MacroTestCase):
    """Import settings without macros while a macro repeats forever. Validate that the
    macro stops switching scenes.

    """

    def setup(self):
        self.import_settings(
            [
                macro_settings(
                    MACRO_ID,
                    "Forever",
                    self.scene_cycle_actions(),
                    repeat_mode=MacroRepeatMode.FOREVER,
                )
            ]
        )

    def run(self):
        self.moblin.start_macro(MACRO_ID)
        self.wait_for_scene_cycles(1)
        self.import_settings([])
        self.assert_scene_unchanged(self.empty_scene_id)


def tests(moblin: Moblin):
    return [
        MacroSwitchScenes(moblin),
        MacroMuteAndUnmute(moblin),
        MacroRepeatCount(moblin),
        MacroRepeatForeverStop(moblin),
        MacroNoActions(moblin),
        MacroNoActionsRepeatForever(moblin),
        MacroRunsItself(moblin),
        MacroMutualRecursion(moblin),
        MacroIfConditions(moblin),
        MacroIfMutedVariable(moblin),
        MacroIfSkipsPastEnd(moblin),
        MacroSubMacroRepeatForever(moblin),
        MacroStopDuringDelayAndRestart(moblin),
        MacroChatBotRunAndCancel(moblin),
        MacroImportSettingsWhileRunning(moblin),
    ]
