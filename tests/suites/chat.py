import logging
import random
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from systest_moblin.ffmpeg import ffmpeg_run

from ..utils import chat_message
from ..utils import twitch_event_sub as event_sub
from ..utils.config import WEB_SERVER_PORT
from ..utils.generate_device_settings import EMPTY_SCENE_SETTINGS
from ..utils.generate_device_settings import FRONT_SCENE_SETTINGS
from ..utils.generate_device_settings import RECORD_STREAM_SETTINGS
from ..utils.generate_device_settings import SCREEN_SCENE_SETTINGS
from ..utils.generate_device_settings import Alignment
from ..utils.generate_device_settings import SceneName
from ..utils.generate_device_settings import alerts_widget_settings
from ..utils.generate_device_settings import chat_widget_settings
from ..utils.generate_device_settings import scene_widget_settings
from ..utils.generate_device_settings import uuid
from ..utils.http_server import HttpServer
from ..utils.moblin import Moblin
from ..utils.test_case import TestCase
from ..utils.utils import FILES_DIR
from ..utils.utils import manual_confirmation
from ..utils.utils import manual_validation

LOGGER = logging.getLogger(__name__)
CHAT_WIDGET_ID = uuid()
NUMBER_OF_EMOTES = 100
MESSAGES_PER_SECOND = 10
NUMBER_OF_MESSAGES = 15 * MESSAGES_PER_SECOND
SPAM_EMOTES_PER_MESSAGE = 8
WORDS = ["hi", "chat", "lol", "wow", "gg", "nice", "moblin", "irl", "so", "many", "emotes"]
USERS = ["Alice", "Bob", "Carol", "Dave", "Erin"]
ALERTS_WIDGET_ID = uuid()
ALERT_IMAGE_ID = uuid()
ALERT_SOUND_ID = uuid()
RAIDED_CHANNEL_NAME = "Oscar"


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


class ChatEventsTestCase(TestCase):
    def setup(self):
        alerts = {"sharedChat": True}
        self.moblin.import_settings(
            overrides={
                "streams": [
                    {
                        "name": "Twitch",
                        "enabled": True,
                        "twitchChannelName": event_sub.BROADCASTER_USER_LOGIN,
                        "twitchChannelId": event_sub.BROADCASTER_USER_ID,
                        "twitchLoggedIn": True,
                        "twitchChatAlerts": alerts,
                        "twitchToastAlerts": alerts,
                    }
                ],
                "scenes": [
                    {
                        **FRONT_SCENE_SETTINGS,
                        "widgets": [scene_widget_settings(ALERTS_WIDGET_ID, 0, 0, 100, Alignment.CENTER)],
                    }
                ],
                "widgets": [
                    alerts_widget_settings("Alerts", ALERTS_WIDGET_ID, ALERT_IMAGE_ID, ALERT_SOUND_ID)
                ],
                "alertsMediaGallery": {
                    "bundledImages": [{"id": ALERT_IMAGE_ID, "name": "Moblin pixels"}],
                    "bundledSounds": [{"id": ALERT_SOUND_ID, "name": "Notification 2"}],
                },
            }
        )

    def send(self, *messages: dict):
        for message in messages:
            if self.moblin.is_interactive():
                manual_confirmation("Get ready to validate an event.")
            self.moblin.send_twitch_event_sub_notification(message)
            if not self.moblin.is_interactive():
                time.sleep(2)

    def send_chat(self, *messages: dict):
        for message in messages:
            if self.moblin.is_interactive():
                manual_confirmation("Get ready to validate a chat message.")
            self.moblin.send_chat_message(**message)
            if not self.moblin.is_interactive():
                time.sleep(2)


class ChatTwitchFollows(ChatEventsTestCase):
    """Send follow events."""

    def run(self):
        manual_validation(LOGGER, "An alert, a toast and a chat highlight is shown for each follow.")
        self.send(
            event_sub.follow("Alice"),
            event_sub.follow("Bob"),
        )


class ChatTwitchSubscriptions(ChatEventsTestCase):
    """Send subscription, gift, resubscription, upgrade and watch streak events."""

    def run(self):
        manual_validation(LOGGER, "An alert, a toast and a chat highlight is shown for each event.")
        self.send(
            event_sub.chat_sub("Grace"),
            event_sub.chat_sub("Heidi", tier="1000", is_prime=True),
            event_sub.chat_resub("Ivan", 24, 24, "3000", "Two years strong"),
            event_sub.chat_sub_gift("Judy", "Mallory"),
            event_sub.chat_sub_gift(None, "Uma"),
            event_sub.chat_community_sub_gift("Niaj", 10),
            event_sub.chat_community_sub_gift(None, 3, tier="2000"),
            event_sub.chat_sub_gift(None, "Victor", community_gift_id="1"),
            event_sub.chat_community_sub_gift(None, 1, community_gift_id="1"),
            event_sub.chat_prime_paid_upgrade("Olivia", tier="1000"),
            event_sub.chat_gift_paid_upgrade("Peggy", "Rupert"),
            event_sub.chat_watch_streak("Sybil", 10, "Never missing a stream"),
            event_sub.chat_watch_streak("Trent", 5),
        )


class ChatTwitchSubscriptionEmotes(ChatEventsTestCase):
    """Send resubscription events with emotes in the user message."""

    def run(self):
        manual_validation(LOGGER, "The alert and chat highlight show the emotes in each message.")
        kappa = event_sub.emote_fragment("Kappa", "25")
        four_head = event_sub.emote_fragment("4Head", "354")
        self.send(
            event_sub.chat_resub("Ivan", 12, 12, "1000", [event_sub.text_fragment("Best stream "), kappa]),
            event_sub.chat_resub(
                "Judy",
                3,
                None,
                "2000",
                [kappa, event_sub.text_fragment(" love it "), four_head],
            ),
        )


class ChatTwitchSharedChat(ChatEventsTestCase):
    """Send shared chat subscription, gift, upgrade, raid and watch streak events."""

    def run(self):
        manual_validation(LOGGER, "Each chat highlight shows that it comes from the Partner channel.")
        self.send(
            event_sub.chat_sub("Alice", shared=True),
            event_sub.chat_sub("Bob", tier="2000", is_prime=True, shared=True),
            event_sub.chat_resub("Carol", 7, 3, "1000", "Hello from the other side", shared=True),
            event_sub.chat_sub_gift("Dave", "Eve", shared=True),
            event_sub.chat_sub_gift(None, "Walter", shared=True),
            event_sub.chat_community_sub_gift("Frank", 5, shared=True),
            event_sub.chat_community_sub_gift(None, 3, tier="2000", shared=True),
            event_sub.chat_sub_gift(None, "Xavier", shared=True, community_gift_id="2"),
            event_sub.chat_community_sub_gift(None, 1, shared=True, community_gift_id="2"),
            event_sub.chat_prime_paid_upgrade("Grace", shared=True),
            event_sub.chat_gift_paid_upgrade("Heidi", "Ivan", shared=True),
            event_sub.chat_watch_streak("Mallory", 8, "Shared streak", shared=True),
            event_sub.chat_watch_streak("Foo", 8, shared=True),
            event_sub.chat_shared_raid("Judy", 123),
        )


class ChatTwitchCheers(ChatEventsTestCase):
    """Send cheer events."""

    def run(self):
        manual_validation(LOGGER, "An alert, a toast and a chat highlight is shown for each cheer.")
        self.send(
            event_sub.cheer("Victor", 100, "Cheer100 keep it up!"),
            event_sub.cheer(None, 5000),
            event_sub.cheer("Walter", 1, "Cheer1"),
        )


class ChatTwitchRewards(ChatEventsTestCase):
    """Send channel points redemption events."""

    def run(self):
        manual_validation(LOGGER, "A toast and a chat highlight is shown for each redemption.")
        self.send(
            event_sub.channel_points_custom_reward_redemption_add("Wendy", "Hydrate", 500, "Drink water"),
            event_sub.channel_points_custom_reward_redemption_add("Xavier", "Do a push-up", 1000),
        )


class ChatTwitchIncomingRaids(ChatEventsTestCase):
    """Send incoming raid events."""

    def run(self):
        manual_validation(LOGGER, "An alert, a toast and a chat highlight is shown for each raid.")
        self.send(
            event_sub.incoming_raid("Yvonne", 42),
            event_sub.incoming_raid("Zach", 1),
        )


class ChatTwitchHypeTrain(ChatEventsTestCase):
    """Send hype train begin, progress and end events."""

    def run(self):
        manual_validation(LOGGER, "The hype train status shows level and progress until it ends.")
        self.send(
            event_sub.hype_train_begin(1, 100, 500),
            event_sub.hype_train_progress(1, 300, 500),
            event_sub.hype_train_progress(2, 100, 800),
            event_sub.hype_train_progress(2, 700, 800),
            event_sub.hype_train_progress(3, 50, 1200),
            event_sub.hype_train_end(3),
        )


class ChatTwitchPoll(ChatEventsTestCase):
    """Send poll begin, progress and end events."""

    def run(self):
        manual_validation(LOGGER, "The poll shows the votes as they come in and then the winner.")
        poll_id = uuid()
        title = "Which game next?"
        self.send(
            event_sub.poll_begin(poll_id, title, ["Minecraft", "Fortnite", "Chess"]),
            event_sub.poll_progress(poll_id, title, [("Minecraft", 3), ("Fortnite", 1), ("Chess", 0)]),
            event_sub.poll_progress(poll_id, title, [("Minecraft", 5), ("Fortnite", 8), ("Chess", 2)]),
            event_sub.poll_progress(poll_id, title, [("Minecraft", 9), ("Fortnite", 12), ("Chess", 4)]),
            event_sub.poll_end(poll_id, title, [("Minecraft", 10), ("Fortnite", 15), ("Chess", 5)]),
        )


class ChatTwitchPollCancelled(ChatEventsTestCase):
    """Send poll begin, progress and cancelled end events."""

    def run(self):
        manual_validation(LOGGER, "The poll is shown as cancelled.")
        poll_id = uuid()
        title = "Pizza or tacos?"
        self.send(
            event_sub.poll_begin(poll_id, title, ["Pizza", "Tacos"]),
            event_sub.poll_progress(poll_id, title, [("Pizza", 2), ("Tacos", 2)]),
            event_sub.poll_end(poll_id, title, [("Pizza", 2), ("Tacos", 2)], status="archived"),
        )


class ChatTwitchPrediction(ChatEventsTestCase):
    """Send prediction begin, progress, lock and end events."""

    def run(self):
        manual_validation(
            LOGGER, "The prediction shows channel points as they come in, then locks and resolves."
        )
        prediction_id = uuid()
        title = "Will I win this round?"
        outcomes = [("Yes", 12, 3400), ("No", 30, 9100)]
        self.send(
            event_sub.prediction_begin(prediction_id, title, ["Yes", "No"]),
            event_sub.prediction_progress(prediction_id, title, [("Yes", 3, 500), ("No", 7, 1200)]),
            event_sub.prediction_progress(prediction_id, title, [("Yes", 8, 2100), ("No", 20, 6000)]),
            event_sub.prediction_lock(prediction_id, title, outcomes),
            event_sub.prediction_end(prediction_id, title, outcomes, winning_outcome_index=0),
        )


class ChatTwitchPredictionCancelled(ChatEventsTestCase):
    """Send prediction begin, progress and cancelled end events."""

    def run(self):
        manual_validation(LOGGER, "The prediction is shown as cancelled.")
        prediction_id = uuid()
        title = "Sub 10 minutes?"
        outcomes = [("Yes", 5, 800), ("No", 4, 600), ("Exactly 10", 1, 100)]
        self.send(
            event_sub.prediction_begin(prediction_id, title, ["Yes", "No", "Exactly 10"]),
            event_sub.prediction_progress(prediction_id, title, outcomes),
            event_sub.prediction_end(prediction_id, title, outcomes, winning_outcome_index=None),
        )


class ChatTwitchAdBreak(ChatEventsTestCase):
    """Send manual and automatic ad break begin events."""

    def run(self):
        manual_validation(LOGGER, "A toast is shown for each commercial and the ads status counts down.")
        self.send(
            event_sub.ad_break_begin(90, is_automatic=False),
            event_sub.ad_break_begin(30, is_automatic=True),
        )


class ChatTwitchOutgoingRaid(ChatEventsTestCase):
    """Send raid started and raid completed events."""

    def run(self):
        manual_validation(
            LOGGER,
            f"The raid status shows raiding {RAIDED_CHANNEL_NAME} and then raid completed.",
        )
        self.send(
            event_sub.moderate_raid(RAIDED_CHANNEL_NAME, 42),
            event_sub.outgoing_raid(RAIDED_CHANNEL_NAME, 42),
        )


class ChatTwitchOutgoingRaidCancelled(ChatEventsTestCase):
    """Send raid started and raid cancelled events."""

    def run(self):
        manual_validation(
            LOGGER,
            f"The raid status shows raiding {RAIDED_CHANNEL_NAME} and then raid cancelled.",
        )
        self.send(
            event_sub.moderate_raid(RAIDED_CHANNEL_NAME, 42),
            event_sub.moderate_unraid(RAIDED_CHANNEL_NAME),
        )


class ChatTwitchFirstMessage(ChatEventsTestCase):
    """Send first time chatter message."""

    def run(self):
        manual_validation(LOGGER, "A first message chat highlight is shown for the first two messages.")
        highlight = chat_message.first_message_highlight()
        self.send_chat(
            {
                "display_name": "Alice",
                "text": "Hello everyone!",
                "highlight": highlight,
                "is_moderator": False,
            },
            {"display_name": "Bob", "text": "First time here", "highlight": highlight, "is_moderator": False},
        )


class ChatTwitchAnnouncement(ChatEventsTestCase):
    """Send announcement chat message."""

    def run(self):
        manual_validation(LOGGER, "A moderator shield and an announcement highlight is shown.")
        self.send_chat(
            {
                "display_name": "Carol",
                "text": "Stream starts in five minutes",
                "is_moderator": True,
                "highlight": chat_message.announcement_highlight(),
            }
        )


class ChatTwitchModerator(ChatEventsTestCase):
    """Send moderator chat message."""

    def run(self):
        manual_validation(LOGGER, "A moderator shield and an announcement highlight is shown.")
        self.send_chat({"display_name": "Alice", "text": "Behave in chat please", "is_moderator": True})


class ChatTwitchGigantifiedEmote(ChatEventsTestCase):
    """Send gigantified emote messages."""

    def run(self):
        manual_validation(LOGGER, "A gigantified emote chat highlight is shown for each message.")
        highlight = chat_message.gigantified_emote_highlight()
        kappa = {
            "id": 1,
            "url": {
                "moving": "https://static-cdn.jtvnw.net/emoticons/v2/25/default/dark/3.0",
                "still": "https://static-cdn.jtvnw.net/emoticons/v2/25/static/dark/3.0",
            },
        }
        self.send_chat(
            {"display_name": "Carol", "text": "", "segments": [kappa], "highlight": highlight},
            {
                "display_name": "Dave",
                "text": "",
                "segments": [{"id": 0, "text": "Look at this "}, kappa],
                "highlight": highlight,
            },
        )


class ChatBigGif(ChatEventsTestCase):
    """Send big GIF messages."""

    def run(self):
        manual_validation(LOGGER, "A big GIF is shown in chat for each message.")
        self.send_chat(
            {
                "display_name": "Eve",
                "text": "",
                "segments": chat_message.big_gif_segments(
                    "https://media.giphy.com/media/l0MYDEPLWRWbJoRuU/100.gif"
                ),
            },
        )


class ChatYouTubeSuperSticker(ChatEventsTestCase):
    """Send a YouTube Super Sticker with an amount and no message text."""

    def run(self):
        manual_validation(
            LOGGER,
            "A YouTube Super Sticker shows in chat and activity feed with its amount in the message text, in both compact and non-compact events.",
        )
        self.send_chat(
            {
                "platform": "youTube",
                "display_name": "Frank",
                "text": "sent a $5.00 Super Sticker!",
                "highlight": chat_message.super_sticker_highlight(),
            }
        )


class ChatYouTubeSuperChat(ChatEventsTestCase):
    """Send a YouTube Super Chat with an amount and message text."""

    def run(self):
        manual_validation(
            LOGGER,
            "A YouTube Super Chat shows in chat and activity feed with its amount and message in the message text, in both compact and non-compact events.",
        )
        self.send_chat(
            {
                "platform": "youTube",
                "display_name": "Grace",
                "text": "sent a $10.00 Super Chat! Thanks for the stream!",
                "highlight": chat_message.super_chat_highlight(),
            }
        )


def tests(moblin: Moblin):
    return [
        ChatBotSwitchScene(moblin),
        ChatBotSwitchSceneUsingAlias(moblin),
        ChatBotMuteAndUnmute(moblin),
        ChatBotNotAllowedToSwitchScene(moblin),
        ChatEmotes(moblin),
        ChatTwitchFollows(moblin),
        ChatTwitchSubscriptions(moblin),
        ChatTwitchSubscriptionEmotes(moblin),
        ChatTwitchSharedChat(moblin),
        ChatTwitchCheers(moblin),
        ChatTwitchRewards(moblin),
        ChatTwitchIncomingRaids(moblin),
        ChatTwitchHypeTrain(moblin),
        ChatTwitchPoll(moblin),
        ChatTwitchPollCancelled(moblin),
        ChatTwitchPrediction(moblin),
        ChatTwitchPredictionCancelled(moblin),
        ChatTwitchAdBreak(moblin),
        ChatTwitchOutgoingRaid(moblin),
        ChatTwitchOutgoingRaidCancelled(moblin),
        ChatTwitchFirstMessage(moblin),
        ChatTwitchAnnouncement(moblin),
        ChatTwitchModerator(moblin),
        ChatTwitchGigantifiedEmote(moblin),
        ChatBigGif(moblin),
        ChatYouTubeSuperSticker(moblin),
        ChatYouTubeSuperChat(moblin),
    ]
