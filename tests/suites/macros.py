import time
from collections.abc import Callable
from dataclasses import dataclass

from ..utils import twitch_event_sub as event_sub
from ..utils.generate_device_settings import EMPTY_SCENE_SETTINGS
from ..utils.generate_device_settings import FRONT_SCENE_SETTINGS
from ..utils.generate_device_settings import SCREEN_SCENE_SETTINGS
from ..utils.generate_device_settings import BitrateRateControl
from ..utils.generate_device_settings import MacroEvent
from ..utils.generate_device_settings import MacroIfComparison
from ..utils.generate_device_settings import MacroRepeatMode
from ..utils.generate_device_settings import SceneName
from ..utils.generate_device_settings import macro_delay_action
from ..utils.generate_device_settings import macro_if_action
from ..utils.generate_device_settings import macro_mute_action
from ..utils.generate_device_settings import macro_run_macro_action
from ..utils.generate_device_settings import macro_scene_action
from ..utils.generate_device_settings import macro_settings
from ..utils.generate_device_settings import macro_wait_for_event_action
from ..utils.generate_device_settings import uuid
from ..utils.mediamtx import MediaMtx
from ..utils.moblin import Moblin
from ..utils.test_case import TestCase

MUTED = "🔇"
DELAY = 2
MACRO_ID = uuid()
OTHER_MACRO_ID = uuid()
TWITCH_STREAM_SETTINGS = {
    "name": "Twitch",
    "enabled": True,
    "twitchChannelName": event_sub.BROADCASTER_USER_LOGIN,
    "twitchChannelId": event_sub.BROADCASTER_USER_ID,
    "twitchLoggedIn": True,
}


@dataclass
class TwitchEvent:
    name: str
    event: MacroEvent
    message: Callable[[], dict]
    other_message: Callable[[], dict]


@dataclass
class TwitchAmountEvent:
    name: str
    event: MacroEvent
    minimum_amount: int
    message: Callable[[int], dict]


TWITCH_EVENTS = [
    TwitchEvent(
        "Follow",
        MacroEvent.TWITCH_FOLLOW,
        lambda: event_sub.follow("Alice"),
        lambda: event_sub.chat_sub("Bob"),
    ),
    TwitchEvent(
        "Subscription",
        MacroEvent.TWITCH_SUBSCRIPTION,
        lambda: event_sub.chat_sub("Alice"),
        lambda: event_sub.follow("Bob"),
    ),
    TwitchEvent(
        "GiftSubscription",
        MacroEvent.TWITCH_GIFT_SUBSCRIPTION,
        lambda: event_sub.chat_community_sub_gift("Alice", 5),
        lambda: event_sub.chat_sub("Bob"),
    ),
    TwitchEvent(
        "Resubscription",
        MacroEvent.TWITCH_RESUBSCRIPTION,
        lambda: event_sub.chat_resub("Alice", 3, 3, "1000", "Hello"),
        lambda: event_sub.chat_sub("Bob"),
    ),
    TwitchEvent(
        "Reward",
        MacroEvent.TWITCH_REWARD,
        lambda: event_sub.channel_points_custom_reward_redemption_add("Alice", "Hydrate"),
        lambda: event_sub.follow("Bob"),
    ),
    TwitchEvent(
        "Raid",
        MacroEvent.TWITCH_RAID,
        lambda: event_sub.incoming_raid("Alice", 10),
        lambda: event_sub.follow("Bob"),
    ),
    TwitchEvent(
        "Cheer",
        MacroEvent.TWITCH_CHEER,
        lambda: event_sub.cheer("Alice", 100),
        lambda: event_sub.follow("Bob"),
    ),
    TwitchEvent(
        "WatchStreak",
        MacroEvent.TWITCH_WATCH_STREAK,
        lambda: event_sub.chat_watch_streak("Alice", 5),
        lambda: event_sub.follow("Bob"),
    ),
]
TWITCH_AMOUNT_EVENTS = [
    TwitchAmountEvent("Cheer", MacroEvent.TWITCH_CHEER, 100, lambda bits: event_sub.cheer("Alice", bits)),
    TwitchAmountEvent(
        "Raid",
        MacroEvent.TWITCH_RAID,
        10,
        lambda viewers: event_sub.incoming_raid("Alice", viewers),
    ),
    TwitchAmountEvent(
        "GiftSubscription",
        MacroEvent.TWITCH_GIFT_SUBSCRIPTION,
        5,
        lambda total: event_sub.chat_community_sub_gift("Alice", total),
    ),
    TwitchAmountEvent(
        "Resubscription",
        MacroEvent.TWITCH_RESUBSCRIPTION,
        12,
        lambda months: event_sub.chat_resub("Alice", months, months, "1000", ""),
    ),
    TwitchAmountEvent(
        "WatchStreak",
        MacroEvent.TWITCH_WATCH_STREAK,
        5,
        lambda count: event_sub.chat_watch_streak("Alice", count),
    ),
]


class MacroTestCase(TestCase):
    def __init__(self, moblin: Moblin, name: str | None = None):
        super().__init__(moblin, name)
        self.empty_scene_id = uuid()
        self.screen_scene_id = uuid()
        self.front_scene_id = uuid()
        self.macro_ids: list[str] = []

    def teardown(self):
        for macro_id in self.macro_ids:
            self.moblin.stop_macro(macro_id)
        self.moblin.set_muted(False)
        super().teardown()

    def import_settings(
        self,
        macros: list[dict],
        chat: dict | None = None,
        stream: dict | None = None,
        front_scene: bool = False,
    ):
        overrides = {"scenes": self.scenes_settings(front_scene), "macros": {"macros": macros}}
        if chat is not None:
            overrides["chat"] = chat
        if stream is not None:
            overrides["streams"] = [stream]
        self.moblin.import_settings(overrides=overrides)
        self.macro_ids = [macro["id"] for macro in macros]
        self.moblin.set_scene(SceneName.EMPTY)
        self.moblin.wait_for_scene(self.empty_scene_id)

    def scenes_settings(self, front_scene: bool = False) -> list[dict]:
        scenes = [
            {**EMPTY_SCENE_SETTINGS, "id": self.empty_scene_id},
            {**SCREEN_SCENE_SETTINGS, "id": self.screen_scene_id},
        ]
        if front_scene:
            scenes.append({**FRONT_SCENE_SETTINGS, "id": self.front_scene_id})
        return scenes

    def import_wait_for_event_settings(self, action: dict, stream: dict | None = None):
        self.import_settings(
            [macro_settings(MACRO_ID, "Wait", [action, macro_scene_action(self.screen_scene_id)])],
            stream=TWITCH_STREAM_SETTINGS if stream is None else stream,
        )

    def send_twitch_event(self, message: dict):
        self.moblin.send_twitch_event_sub_notification(message)

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


class MacroWaitForTwitchEvent(MacroTestCase):
    """Run a macro that waits for a Twitch event. Validate that an unrelated event is
    ignored and that the awaited event lets the macro continue.

    """

    def __init__(self, moblin: Moblin, twitch_event: TwitchEvent):
        super().__init__(moblin, f"MacroWaitForTwitch{twitch_event.name}")
        self.twitch_event = twitch_event

    def setup(self):
        self.import_wait_for_event_settings(macro_wait_for_event_action(self.twitch_event.event))

    def run(self):
        self.moblin.start_macro(MACRO_ID)
        self.moblin.wait_for_macro_running(MACRO_ID, True)
        self.send_twitch_event(self.twitch_event.other_message())
        self.assert_scene_unchanged(self.empty_scene_id, seconds=2)
        self.assert_true(self.moblin.is_macro_running(MACRO_ID), "Macro not running")
        self.send_twitch_event(self.twitch_event.message())
        self.moblin.wait_for_scene(self.screen_scene_id)
        self.moblin.wait_for_macro_running(MACRO_ID, False)


class MacroWaitForTwitchEventMinimumAmount(MacroTestCase):
    """Run a macro that waits for a Twitch event with a minimum amount. Validate that an
    event below the minimum is ignored and that an event at the minimum lets the macro
    continue.

    """

    def __init__(self, moblin: Moblin, twitch_event: TwitchAmountEvent):
        super().__init__(moblin, f"MacroWaitForTwitch{twitch_event.name}MinimumAmount")
        self.twitch_event = twitch_event

    def setup(self):
        self.import_wait_for_event_settings(
            macro_wait_for_event_action(self.twitch_event.event, self.twitch_event.minimum_amount)
        )

    def run(self):
        self.moblin.start_macro(MACRO_ID)
        self.moblin.wait_for_macro_running(MACRO_ID, True)
        self.send_twitch_event(self.twitch_event.message(self.twitch_event.minimum_amount - 1))
        self.assert_scene_unchanged(self.empty_scene_id, seconds=2)
        self.assert_true(self.moblin.is_macro_running(MACRO_ID), "Macro not running")
        self.send_twitch_event(self.twitch_event.message(self.twitch_event.minimum_amount))
        self.moblin.wait_for_scene(self.screen_scene_id)
        self.moblin.wait_for_macro_running(MACRO_ID, False)


class MacroWaitForTwitchRewardText(MacroTestCase):
    """Run a macro that waits for a Twitch reward with a given title. Validate that other
    rewards are ignored and that the title comparison ignores case and surrounding
    whitespace. Then run a macro that waits for any reward.

    """

    def setup(self):
        self.import_settings(
            [
                macro_settings(
                    MACRO_ID,
                    "Hydrate",
                    [
                        macro_wait_for_event_action(MacroEvent.TWITCH_REWARD, text="Hydrate"),
                        macro_scene_action(self.screen_scene_id),
                    ],
                ),
                macro_settings(
                    OTHER_MACRO_ID,
                    "Any",
                    [
                        macro_wait_for_event_action(MacroEvent.TWITCH_REWARD),
                        macro_scene_action(self.empty_scene_id),
                    ],
                ),
            ],
            stream=TWITCH_STREAM_SETTINGS,
        )

    def run(self):
        self.moblin.start_macro(MACRO_ID)
        self.moblin.wait_for_macro_running(MACRO_ID, True)
        self.send_twitch_event(event_sub.channel_points_custom_reward_redemption_add("Alice", "Coffee"))
        self.assert_scene_unchanged(self.empty_scene_id, seconds=2)
        self.send_twitch_event(event_sub.channel_points_custom_reward_redemption_add("Bob", " hYdRaTe "))
        self.moblin.wait_for_scene(self.screen_scene_id)
        self.moblin.wait_for_macro_running(MACRO_ID, False)
        self.moblin.start_macro(OTHER_MACRO_ID)
        self.moblin.wait_for_macro_running(OTHER_MACRO_ID, True)
        self.send_twitch_event(event_sub.channel_points_custom_reward_redemption_add("Carol", "Coffee"))
        self.moblin.wait_for_scene(self.empty_scene_id)
        self.moblin.wait_for_macro_running(OTHER_MACRO_ID, False)


class MacroWaitForSceneSwitched(MacroTestCase):
    """Run a macro that waits for a switch to a given scene, then for a switch to any
    scene. Validate that switches to other scenes are ignored and that the macro's own
    scene switch satisfies its following wait.

    """

    def setup(self):
        self.import_settings(
            [
                macro_settings(
                    MACRO_ID,
                    "Scene",
                    [
                        macro_wait_for_event_action(MacroEvent.SCENE_SWITCHED, scene_id=self.screen_scene_id),
                        macro_mute_action(True),
                        macro_wait_for_event_action(MacroEvent.SCENE_SWITCHED),
                        macro_scene_action(self.empty_scene_id),
                        macro_wait_for_event_action(MacroEvent.SCENE_SWITCHED),
                        macro_mute_action(False),
                    ],
                )
            ],
            front_scene=True,
        )

    def run(self):
        self.wait_for_muted(False)
        self.moblin.start_macro(MACRO_ID)
        self.moblin.wait_for_macro_running(MACRO_ID, True)
        self.moblin.set_scene(SceneName.FRONT)
        self.moblin.wait_for_scene(self.front_scene_id)
        self.assert_muted_unchanged(False, seconds=2)
        self.moblin.set_scene(SceneName.SCREEN)
        self.wait_for_muted(True)
        self.assert_scene_unchanged(self.screen_scene_id, seconds=2)
        self.moblin.set_scene(SceneName.FRONT)
        self.moblin.wait_for_scene(self.empty_scene_id)
        self.wait_for_muted(False)
        self.moblin.wait_for_macro_running(MACRO_ID, False)


class MacroWaitForStreamStartedAndStopped(MacroTestCase):
    """Run a macro that mutes when the stream starts and unmutes when it stops."""

    def setup(self):
        self.import_settings(
            [
                macro_settings(
                    MACRO_ID,
                    "Stream",
                    [
                        macro_wait_for_event_action(MacroEvent.STREAM_STARTED),
                        macro_mute_action(True),
                        macro_wait_for_event_action(MacroEvent.STREAM_STOPPED),
                        macro_mute_action(False),
                    ],
                )
            ],
            stream={
                "enabled": True,
                "bitrateRateControl": BitrateRateControl.CBR,
                "url": self.moblin.tester_rtmp_url("test"),
                "rtmp": {"adaptiveBitrateEnabled": False},
            },
        )

    def run(self):
        self.wait_for_muted(False)
        self.moblin.start_macro(MACRO_ID)
        self.moblin.wait_for_macro_running(MACRO_ID, True)
        with MediaMtx():
            self.moblin.go_live()
            self.wait_for_muted(True)
            self.assert_true(self.moblin.is_macro_running(MACRO_ID), "Macro not running")
            self.moblin.end()
            self.wait_for_muted(False)
            self.moblin.wait_for_macro_running(MACRO_ID, False)


class MacroWaitForRecordingStartedAndStopped(MacroTestCase):
    """Run a macro that mutes when recording starts and unmutes when it stops."""

    def setup(self):
        self.import_settings(
            [
                macro_settings(
                    MACRO_ID,
                    "Recording",
                    [
                        macro_wait_for_event_action(MacroEvent.RECORDING_STARTED),
                        macro_mute_action(True),
                        macro_wait_for_event_action(MacroEvent.RECORDING_STOPPED),
                        macro_mute_action(False),
                    ],
                )
            ]
        )

    def run(self):
        self.wait_for_muted(False)
        self.moblin.start_macro(MACRO_ID)
        self.moblin.wait_for_macro_running(MACRO_ID, True)
        self.moblin.start_recording()
        self.wait_for_muted(True)
        self.assert_true(self.moblin.is_macro_running(MACRO_ID), "Macro not running")
        self.moblin.stop_recording()
        self.wait_for_muted(False)
        self.moblin.wait_for_macro_running(MACRO_ID, False)

    def teardown(self):
        super().teardown()
        self.moblin.delete_all_recordings()


class MacroWaitForEventStopAndRestart(MacroTestCase):
    """Stop a macro while it waits for an event. Validate that the event no longer
    continues the macro and that the macro waits again after a restart.

    """

    def setup(self):
        self.import_wait_for_event_settings(macro_wait_for_event_action(MacroEvent.TWITCH_FOLLOW))

    def run(self):
        self.moblin.start_macro(MACRO_ID)
        self.moblin.wait_for_macro_running(MACRO_ID, True)
        self.moblin.stop_macro(MACRO_ID)
        self.moblin.wait_for_macro_running(MACRO_ID, False)
        self.send_twitch_event(event_sub.follow("Alice"))
        self.assert_scene_unchanged(self.empty_scene_id, seconds=2)
        self.moblin.start_macro(MACRO_ID)
        self.moblin.wait_for_macro_running(MACRO_ID, True)
        self.send_twitch_event(event_sub.follow("Bob"))
        self.moblin.wait_for_scene(self.screen_scene_id)
        self.moblin.wait_for_macro_running(MACRO_ID, False)


class MacroWaitForEventInSubMacro(MacroTestCase):
    """Run a macro whose sub macro waits for an event. Validate that the event continues
    the sub macro and then the parent macro.

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
                        macro_wait_for_event_action(MacroEvent.TWITCH_FOLLOW),
                        macro_mute_action(True),
                    ],
                ),
            ],
            stream=TWITCH_STREAM_SETTINGS,
        )

    def run(self):
        self.wait_for_muted(False)
        self.moblin.start_macro(MACRO_ID)
        self.moblin.wait_for_scene(self.screen_scene_id)
        self.assert_scene_unchanged(self.screen_scene_id, seconds=2)
        self.assert_true(self.moblin.is_macro_running(MACRO_ID), "Macro not running")
        self.send_twitch_event(event_sub.follow("Alice"))
        self.wait_for_muted(True)
        self.moblin.wait_for_scene(self.empty_scene_id)
        self.moblin.wait_for_macro_running(MACRO_ID, False)


class MacroWaitForEventTwoMacros(MacroTestCase):
    """Run two macros waiting for the same event. Validate that one event continues both."""

    def setup(self):
        self.import_settings(
            [
                macro_settings(
                    MACRO_ID,
                    "Scene",
                    [
                        macro_wait_for_event_action(MacroEvent.TWITCH_FOLLOW),
                        macro_scene_action(self.screen_scene_id),
                    ],
                ),
                macro_settings(
                    OTHER_MACRO_ID,
                    "Mute",
                    [
                        macro_wait_for_event_action(MacroEvent.TWITCH_FOLLOW),
                        macro_mute_action(True),
                    ],
                ),
            ],
            stream=TWITCH_STREAM_SETTINGS,
        )

    def run(self):
        self.wait_for_muted(False)
        self.moblin.start_macro(MACRO_ID)
        self.moblin.start_macro(OTHER_MACRO_ID)
        self.moblin.wait_for_macro_running(MACRO_ID, True)
        self.moblin.wait_for_macro_running(OTHER_MACRO_ID, True)
        self.send_twitch_event(event_sub.follow("Alice"))
        self.moblin.wait_for_scene(self.screen_scene_id)
        self.wait_for_muted(True)
        self.moblin.wait_for_macro_running(MACRO_ID, False)
        self.moblin.wait_for_macro_running(OTHER_MACRO_ID, False)


class MacroWaitForEventRepeatForever(MacroTestCase):
    """Run a macro forever that switches scene on every follow. The macro mutes and
    unmutes right before each wait so the test knows when it is waiting. Validate that
    it keeps reacting to follows and that it can be stopped while waiting.

    """

    def setup(self):
        self.import_settings(
            [
                macro_settings(
                    MACRO_ID,
                    "Follows",
                    [
                        macro_mute_action(True),
                        macro_wait_for_event_action(MacroEvent.TWITCH_FOLLOW),
                        macro_scene_action(self.screen_scene_id),
                        macro_mute_action(False),
                        macro_wait_for_event_action(MacroEvent.TWITCH_FOLLOW),
                        macro_scene_action(self.empty_scene_id),
                    ],
                    repeat_mode=MacroRepeatMode.FOREVER,
                )
            ],
            stream=TWITCH_STREAM_SETTINGS,
        )

    def run(self):
        self.wait_for_muted(False)
        self.moblin.start_macro(MACRO_ID)
        for _ in range(2):
            self.wait_for_muted(True)
            self.send_twitch_event(event_sub.follow("Alice"))
            self.moblin.wait_for_scene(self.screen_scene_id)
            self.wait_for_muted(False)
            self.send_twitch_event(event_sub.follow("Bob"))
            self.moblin.wait_for_scene(self.empty_scene_id)
        self.wait_for_muted(True)
        self.assert_true(self.moblin.is_macro_running(MACRO_ID), "Macro not running")
        self.moblin.stop_macro(MACRO_ID)
        self.moblin.wait_for_macro_running(MACRO_ID, False)
        self.send_twitch_event(event_sub.follow("Carol"))
        self.assert_scene_unchanged(self.empty_scene_id, seconds=2)


class MacroWaitForEventQueued(MacroTestCase):
    """Send two follows back-to-back to a macro that waits for a follow twice with a
    delay in between. Validate that the second follow is queued and continues the macro
    after the delay, and that a follow after the macro has finished is ignored.

    """

    def setup(self):
        self.import_settings(
            [
                macro_settings(
                    MACRO_ID,
                    "Queued",
                    [
                        macro_wait_for_event_action(MacroEvent.TWITCH_FOLLOW),
                        macro_scene_action(self.screen_scene_id),
                        macro_delay_action(DELAY),
                        macro_wait_for_event_action(MacroEvent.TWITCH_FOLLOW),
                        macro_scene_action(self.empty_scene_id),
                    ],
                )
            ],
            stream=TWITCH_STREAM_SETTINGS,
        )

    def run(self):
        self.moblin.start_macro(MACRO_ID)
        self.moblin.wait_for_macro_running(MACRO_ID, True)
        self.send_twitch_event(event_sub.follow("Alice"))
        self.send_twitch_event(event_sub.follow("Bob"))
        self.moblin.wait_for_scene(self.screen_scene_id)
        self.moblin.wait_for_scene(self.empty_scene_id)
        self.moblin.wait_for_macro_running(MACRO_ID, False)
        self.send_twitch_event(event_sub.follow("Carol"))
        self.assert_scene_unchanged(self.empty_scene_id, seconds=2)


class MacroWaitForEventQueuedInSubMacro(MacroTestCase):
    """Send a follow while a parent macro delays before running a sub macro that waits
    for a follow. Validate that the sub macro consumes the queued follow.

    """

    def setup(self):
        self.import_settings(
            [
                macro_settings(
                    MACRO_ID,
                    "Parent",
                    [
                        macro_delay_action(DELAY),
                        macro_run_macro_action(OTHER_MACRO_ID),
                    ],
                ),
                macro_settings(
                    OTHER_MACRO_ID,
                    "Child",
                    [
                        macro_wait_for_event_action(MacroEvent.TWITCH_FOLLOW),
                        macro_mute_action(True),
                    ],
                ),
            ],
            stream=TWITCH_STREAM_SETTINGS,
        )

    def run(self):
        self.wait_for_muted(False)
        self.moblin.start_macro(MACRO_ID)
        self.moblin.wait_for_macro_running(MACRO_ID, True)
        self.send_twitch_event(event_sub.follow("Alice"))
        self.wait_for_muted(True)
        self.moblin.wait_for_macro_running(MACRO_ID, False)


class MacroWaitForEventQueueClearedOnStop(MacroTestCase):
    """Send a follow while a macro delays before waiting for a follow, then stop and
    restart the macro. Validate that the queued follow is discarded by the stop and that
    a new follow continues the restarted macro.

    """

    def setup(self):
        self.import_settings(
            [
                macro_settings(
                    MACRO_ID,
                    "Cleared",
                    [
                        macro_delay_action(DELAY),
                        macro_wait_for_event_action(MacroEvent.TWITCH_FOLLOW),
                        macro_scene_action(self.screen_scene_id),
                    ],
                )
            ],
            stream=TWITCH_STREAM_SETTINGS,
        )

    def run(self):
        self.moblin.start_macro(MACRO_ID)
        self.moblin.wait_for_macro_running(MACRO_ID, True)
        self.send_twitch_event(event_sub.follow("Alice"))
        self.moblin.stop_macro(MACRO_ID)
        self.moblin.wait_for_macro_running(MACRO_ID, False)
        self.moblin.start_macro(MACRO_ID)
        self.moblin.wait_for_macro_running(MACRO_ID, True)
        self.assert_scene_unchanged(self.empty_scene_id, seconds=DELAY + 2)
        self.assert_true(self.moblin.is_macro_running(MACRO_ID), "Macro not running")
        self.send_twitch_event(event_sub.follow("Bob"))
        self.moblin.wait_for_scene(self.screen_scene_id)
        self.moblin.wait_for_macro_running(MACRO_ID, False)


class MacroWaitForEventBeforeStartIgnored(MacroTestCase):
    """Send a follow before starting a macro that waits for a follow. Validate that the
    macro does not continue until a follow arrives after it was started.

    """

    def setup(self):
        self.import_wait_for_event_settings(macro_wait_for_event_action(MacroEvent.TWITCH_FOLLOW))

    def run(self):
        self.send_twitch_event(event_sub.follow("Alice"))
        self.moblin.start_macro(MACRO_ID)
        self.moblin.wait_for_macro_running(MACRO_ID, True)
        self.assert_scene_unchanged(self.empty_scene_id, seconds=2)
        self.assert_true(self.moblin.is_macro_running(MACRO_ID), "Macro not running")
        self.send_twitch_event(event_sub.follow("Bob"))
        self.moblin.wait_for_scene(self.screen_scene_id)
        self.moblin.wait_for_macro_running(MACRO_ID, False)


class MacroWaitForEventSkipsEarlierEvents(MacroTestCase):
    """Send a follow and then a cheer while a macro delays before waiting for a cheer and
    then a follow. Validate that the cheer continues the macro and that the follow that
    arrived before the cheer is discarded, so the macro waits for a new follow.

    """

    def setup(self):
        self.import_settings(
            [
                macro_settings(
                    MACRO_ID,
                    "Skip",
                    [
                        macro_delay_action(DELAY),
                        macro_wait_for_event_action(MacroEvent.TWITCH_CHEER),
                        macro_scene_action(self.screen_scene_id),
                        macro_wait_for_event_action(MacroEvent.TWITCH_FOLLOW),
                        macro_scene_action(self.empty_scene_id),
                    ],
                )
            ],
            stream=TWITCH_STREAM_SETTINGS,
        )

    def run(self):
        self.moblin.start_macro(MACRO_ID)
        self.moblin.wait_for_macro_running(MACRO_ID, True)
        self.send_twitch_event(event_sub.follow("Alice"))
        self.send_twitch_event(event_sub.cheer("Bob", 100))
        self.moblin.wait_for_scene(self.screen_scene_id)
        self.assert_scene_unchanged(self.screen_scene_id, seconds=2)
        self.assert_true(self.moblin.is_macro_running(MACRO_ID), "Macro not running")
        self.send_twitch_event(event_sub.follow("Carol"))
        self.moblin.wait_for_scene(self.empty_scene_id)
        self.moblin.wait_for_macro_running(MACRO_ID, False)


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
        *[MacroWaitForTwitchEvent(moblin, twitch_event) for twitch_event in TWITCH_EVENTS],
        *[
            MacroWaitForTwitchEventMinimumAmount(moblin, twitch_event)
            for twitch_event in TWITCH_AMOUNT_EVENTS
        ],
        MacroWaitForTwitchRewardText(moblin),
        MacroWaitForSceneSwitched(moblin),
        MacroWaitForStreamStartedAndStopped(moblin),
        MacroWaitForRecordingStartedAndStopped(moblin),
        MacroWaitForEventStopAndRestart(moblin),
        MacroWaitForEventInSubMacro(moblin),
        MacroWaitForEventTwoMacros(moblin),
        MacroWaitForEventRepeatForever(moblin),
        MacroWaitForEventQueued(moblin),
        MacroWaitForEventQueuedInSubMacro(moblin),
        MacroWaitForEventQueueClearedOnStop(moblin),
        MacroWaitForEventBeforeStartIgnored(moblin),
        MacroWaitForEventSkipsEarlierEvents(moblin),
    ]
