import logging
import time

from ..utils import chat_message
from ..utils import twitch_event_sub as event_sub
from ..utils.generate_device_settings import FRONT_SCENE_SETTINGS
from ..utils.generate_device_settings import alerts_widget_settings
from ..utils.generate_device_settings import scene_widget_settings
from ..utils.generate_device_settings import uuid
from ..utils.moblin import Moblin
from ..utils.test_case import TestCase
from ..utils.utils import manual_confirmation
from ..utils.utils import manual_validation

LOGGER = logging.getLogger(__name__)
ALERTS_WIDGET_ID = uuid()
ALERT_IMAGE_ID = uuid()
ALERT_SOUND_ID = uuid()
RAIDED_CHANNEL_NAME = "Oscar"


class TwitchEventsTestCase(TestCase):
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
                        "widgets": [scene_widget_settings(ALERTS_WIDGET_ID, 0, 0, 100)],
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


class TwitchEventsFollows(TwitchEventsTestCase):
    """Send follow events."""

    def run(self):
        manual_validation(LOGGER, "An alert, a toast and a chat highlight is shown for each follow.")
        self.send(
            event_sub.follow("Alice"),
            event_sub.follow("Bob"),
        )


class TwitchEventsChat(TwitchEventsTestCase):
    """Send subscription, gift, resubscription, upgrade and watch streak events."""

    def run(self):
        manual_validation(LOGGER, "An alert, a toast and a chat highlight is shown for each event.")
        self.send(
            event_sub.chat_sub("Grace"),
            event_sub.chat_sub("Heidi", tier="1000", is_prime=True),
            event_sub.chat_resub("Ivan", 24, 24, "3000", "Two years strong"),
            event_sub.chat_sub_gift("Judy", "Mallory"),
            event_sub.chat_community_sub_gift("Niaj", 10),
            event_sub.chat_community_sub_gift(None, 3, tier="2000"),
            event_sub.chat_prime_paid_upgrade("Olivia", tier="1000"),
            event_sub.chat_gift_paid_upgrade("Peggy", "Rupert"),
            event_sub.chat_watch_streak("Sybil", 10, "Never missing a stream"),
            event_sub.chat_watch_streak("Trent", 5),
        )


class TwitchEventsSharedChat(TwitchEventsTestCase):
    """Send shared chat subscription, gift, upgrade, raid and watch streak events."""

    def run(self):
        manual_validation(LOGGER, "Each chat highlight shows that it comes from the Partner channel.")
        self.send(
            event_sub.chat_sub("Alice", shared=True),
            event_sub.chat_sub("Bob", tier="2000", is_prime=True, shared=True),
            event_sub.chat_resub("Carol", 7, 3, "1000", "Hello from the other side", shared=True),
            event_sub.chat_sub_gift("Dave", "Eve", shared=True),
            event_sub.chat_community_sub_gift("Frank", 5, shared=True),
            event_sub.chat_community_sub_gift(None, 3, tier="2000", shared=True),
            event_sub.chat_prime_paid_upgrade("Grace", shared=True),
            event_sub.chat_gift_paid_upgrade("Heidi", "Ivan", shared=True),
            event_sub.chat_watch_streak("Mallory", 8, "Shared streak", shared=True),
            event_sub.chat_watch_streak("Foo", 8, shared=True),
            event_sub.chat_shared_raid("Judy", 123),
        )


class TwitchEventsCheers(TwitchEventsTestCase):
    """Send cheer events."""

    def run(self):
        manual_validation(LOGGER, "An alert, a toast and a chat highlight is shown for each cheer.")
        self.send(
            event_sub.cheer("Victor", 100, "Cheer100 keep it up!"),
            event_sub.cheer(None, 5000),
            event_sub.cheer("Walter", 1, "Cheer1"),
        )


class TwitchEventsRewards(TwitchEventsTestCase):
    """Send channel points redemption events."""

    def run(self):
        manual_validation(LOGGER, "A toast and a chat highlight is shown for each redemption.")
        self.send(
            event_sub.channel_points_custom_reward_redemption_add("Wendy", "Hydrate", 500, "Drink water"),
            event_sub.channel_points_custom_reward_redemption_add("Xavier", "Do a push-up", 1000),
        )


class TwitchEventsIncomingRaids(TwitchEventsTestCase):
    """Send incoming raid events."""

    def run(self):
        manual_validation(LOGGER, "An alert, a toast and a chat highlight is shown for each raid.")
        self.send(
            event_sub.incoming_raid("Yvonne", 42),
            event_sub.incoming_raid("Zach", 1),
        )


class TwitchEventsHypeTrain(TwitchEventsTestCase):
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


class TwitchEventsPoll(TwitchEventsTestCase):
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


class TwitchEventsPollCancelled(TwitchEventsTestCase):
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


class TwitchEventsPrediction(TwitchEventsTestCase):
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


class TwitchEventsPredictionCancelled(TwitchEventsTestCase):
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


class TwitchEventsAdBreak(TwitchEventsTestCase):
    """Send manual and automatic ad break begin events."""

    def run(self):
        manual_validation(LOGGER, "A toast is shown for each commercial and the ads status counts down.")
        self.send(
            event_sub.ad_break_begin(90, is_automatic=False),
            event_sub.ad_break_begin(30, is_automatic=True),
        )


class TwitchEventsOutgoingRaid(TwitchEventsTestCase):
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


class TwitchEventsOutgoingRaidCancelled(TwitchEventsTestCase):
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


class TwitchEventsFirstMessage(TwitchEventsTestCase):
    """Send first time chatter messages."""

    def run(self):
        manual_validation(LOGGER, "A first message chat highlight is shown for the first two messages.")
        highlight = chat_message.first_message_highlight()
        self.send_chat(
            {"display_name": "Alice", "text": "Hello everyone!", "highlight": highlight},
            {"display_name": "Bob", "text": "First time here", "highlight": highlight},
            {"display_name": "Alice", "text": "Back again"},
        )


class TwitchEventsGigantifiedEmote(TwitchEventsTestCase):
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


class TwitchEventsBigGif(TwitchEventsTestCase):
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


def tests(moblin: Moblin):
    return [
        TwitchEventsFollows(moblin),
        TwitchEventsChat(moblin),
        TwitchEventsSharedChat(moblin),
        TwitchEventsCheers(moblin),
        TwitchEventsRewards(moblin),
        TwitchEventsIncomingRaids(moblin),
        TwitchEventsHypeTrain(moblin),
        TwitchEventsPoll(moblin),
        TwitchEventsPollCancelled(moblin),
        TwitchEventsPrediction(moblin),
        TwitchEventsPredictionCancelled(moblin),
        TwitchEventsAdBreak(moblin),
        TwitchEventsOutgoingRaid(moblin),
        TwitchEventsOutgoingRaidCancelled(moblin),
        TwitchEventsFirstMessage(moblin),
        TwitchEventsGigantifiedEmote(moblin),
        TwitchEventsBigGif(moblin),
    ]
