import uuid
import zlib
from collections.abc import Sequence
from datetime import UTC
from datetime import datetime
from datetime import timedelta

BROADCASTER_USER_ID = "111"
BROADCASTER_USER_LOGIN = "tester"
BROADCASTER_USER_NAME = "Tester"
SHARED_CHAT_BROADCASTER_USER_ID = "222"
SHARED_CHAT_BROADCASTER_USER_LOGIN = "partner"
SHARED_CHAT_BROADCASTER_USER_NAME = "Partner"


def timestamp(offset: float = 0) -> str:
    return (datetime.now(UTC) + timedelta(seconds=offset)).strftime("%Y-%m-%dT%H:%M:%S.%fZ")


def user_id(name: str) -> str:
    return str(zlib.crc32(name.encode()))


def _broadcaster() -> dict:
    return {
        "broadcaster_user_id": BROADCASTER_USER_ID,
        "broadcaster_user_login": BROADCASTER_USER_LOGIN,
        "broadcaster_user_name": BROADCASTER_USER_NAME,
    }


def _user(name: str | None) -> dict:
    if name is None:
        return {"user_id": None, "user_login": None, "user_name": None}
    return {"user_id": user_id(name), "user_login": name.lower(), "user_name": name}


def _prefixed(prefix: str, name: str) -> dict:
    return {f"{prefix}_{key}": value for key, value in _user(name).items()}


def notification(subscription_type: str, event: dict, version: str = "1") -> dict:
    return {
        "metadata": {
            "message_id": str(uuid.uuid4()),
            "message_type": "notification",
            "message_timestamp": timestamp(),
            "subscription_type": subscription_type,
            "subscription_version": version,
        },
        "payload": {
            "subscription": {
                "id": str(uuid.uuid4()),
                "status": "enabled",
                "type": subscription_type,
                "version": version,
                "condition": {"broadcaster_user_id": BROADCASTER_USER_ID},
                "transport": {"method": "websocket", "session_id": "session"},
                "created_at": timestamp(),
                "cost": 0,
            },
            "event": event,
        },
    }


def follow(user_name: str) -> dict:
    return notification(
        "channel.follow",
        {**_user(user_name), **_broadcaster(), "followed_at": timestamp()},
        version="2",
    )


def chat_notification(
    notice_type: str,
    chatter_user_name: str,
    notice: dict | None = None,
    message: str = "",
    shared: bool = False,
    chatter_is_anonymous: bool = False,
) -> dict:
    source: dict
    if shared:
        source = {
            "source_broadcaster_user_id": SHARED_CHAT_BROADCASTER_USER_ID,
            "source_broadcaster_user_login": SHARED_CHAT_BROADCASTER_USER_LOGIN,
            "source_broadcaster_user_name": SHARED_CHAT_BROADCASTER_USER_NAME,
            "source_message_id": str(uuid.uuid4()),
            "source_badges": [],
        }
    else:
        source = {
            "source_broadcaster_user_id": None,
            "source_broadcaster_user_login": None,
            "source_broadcaster_user_name": None,
            "source_message_id": None,
            "source_badges": None,
        }
    event = {
        **_broadcaster(),
        **source,
        **_prefixed("chatter", chatter_user_name),
        "chatter_is_anonymous": chatter_is_anonymous,
        "color": "#FF4500",
        "badges": [],
        "system_message": "",
        "message_id": str(uuid.uuid4()),
        "message": {"text": message, "fragments": []},
        "notice_type": notice_type,
        "sub": None,
        "resub": None,
        "sub_gift": None,
        "community_sub_gift": None,
        "gift_paid_upgrade": None,
        "prime_paid_upgrade": None,
        "pay_it_forward": None,
        "raid": None,
        "unraid": None,
        "announcement": None,
        "bits_badge_tier": None,
        "charity_donation": None,
        "watch_streak": None,
        "shared_chat_sub": None,
        "shared_chat_resub": None,
        "shared_chat_sub_gift": None,
        "shared_chat_community_sub_gift": None,
        "shared_chat_gift_paid_upgrade": None,
        "shared_chat_prime_paid_upgrade": None,
        "shared_chat_pay_it_forward": None,
        "shared_chat_raid": None,
        "shared_chat_announcement": None,
        notice_type: notice,
    }
    return notification("channel.chat.notification", event)


def _notice_type(name: str, shared: bool) -> str:
    return f"shared_chat_{name}" if shared else name


def chat_sub(user_name: str, tier: str = "1000", is_prime: bool = False, shared: bool = False) -> dict:
    notice_type = _notice_type("sub", shared)
    return chat_notification(
        notice_type,
        user_name,
        {"sub_tier": tier, "is_prime": is_prime, "duration_months": 1},
        shared=shared,
    )


def chat_resub(
    user_name: str,
    cumulative_months: int,
    streak_months: int | None,
    tier: str,
    message: str,
    shared: bool = False,
) -> dict:
    notice_type = _notice_type("resub", shared)
    return chat_notification(
        notice_type,
        user_name,
        {
            "cumulative_months": cumulative_months,
            "duration_months": 1,
            "streak_months": streak_months,
            "sub_tier": tier,
            "is_prime": False,
            "is_gift": False,
            "gifter_is_anonymous": None,
            "gifter_user_id": None,
            "gifter_user_login": None,
            "gifter_user_name": None,
        },
        message,
        shared=shared,
    )


def chat_sub_gift(
    user_name: str,
    recipient_user_name: str,
    tier: str = "1000",
    shared: bool = False,
) -> dict:
    notice_type = _notice_type("sub_gift", shared)
    return chat_notification(
        notice_type,
        user_name,
        {
            "duration_months": 1,
            "cumulative_total": 1,
            **_prefixed("recipient", recipient_user_name),
            "sub_tier": tier,
            "community_gift_id": None,
        },
        shared=shared,
    )


def chat_community_sub_gift(
    user_name: str | None,
    total: int,
    tier: str = "1000",
    shared: bool = False,
) -> dict:
    notice_type = _notice_type("community_sub_gift", shared)
    return chat_notification(
        notice_type,
        user_name or "AnAnonymousGifter",
        {
            "id": str(uuid.uuid4()),
            "total": total,
            "sub_tier": tier,
            "cumulative_total": None if user_name is None else total,
        },
        shared=shared,
        chatter_is_anonymous=user_name is None,
    )


def chat_prime_paid_upgrade(user_name: str, tier: str = "1000", shared: bool = False) -> dict:
    notice_type = _notice_type("prime_paid_upgrade", shared)
    return chat_notification(notice_type, user_name, {"sub_tier": tier}, shared=shared)


def chat_gift_paid_upgrade(user_name: str, gifter_user_name: str, shared: bool = False) -> dict:
    notice_type = _notice_type("gift_paid_upgrade", shared)
    return chat_notification(
        notice_type,
        user_name,
        {"gifter_is_anonymous": False, **_prefixed("gifter", gifter_user_name)},
        shared=shared,
    )


def chat_shared_raid(from_user_name: str, viewer_count: int) -> dict:
    return chat_notification(
        "shared_chat_raid",
        from_user_name,
        {
            **_user(from_user_name),
            "viewer_count": viewer_count,
            "profile_image_url": "",
        },
        shared=True,
    )


def chat_watch_streak(user_name: str, streak_count: int, message: str = "", shared: bool = False) -> dict:
    return chat_notification(
        "watch_streak",
        user_name,
        {"streak_count": streak_count},
        message,
        shared=shared,
    )


def channel_points_custom_reward_redemption_add(
    user_name: str,
    title: str,
    cost: int = 100,
    prompt: str = "",
) -> dict:
    return notification(
        "channel.channel_points_custom_reward_redemption.add",
        {
            "id": str(uuid.uuid4()),
            **_user(user_name),
            **_broadcaster(),
            "user_input": "",
            "status": "unfulfilled",
            "reward": {"id": str(uuid.uuid4()), "title": title, "cost": cost, "prompt": prompt},
            "redeemed_at": timestamp(),
        },
    )


def incoming_raid(from_broadcaster_user_name: str, viewers: int) -> dict:
    return notification(
        "channel.raid",
        {
            **_prefixed("from_broadcaster", from_broadcaster_user_name),
            "to_broadcaster_user_id": BROADCASTER_USER_ID,
            "to_broadcaster_user_login": BROADCASTER_USER_LOGIN,
            "to_broadcaster_user_name": BROADCASTER_USER_NAME,
            "viewers": viewers,
        },
    )


def outgoing_raid(to_broadcaster_user_name: str, viewers: int) -> dict:
    return notification(
        "channel.raid",
        {
            "from_broadcaster_user_id": BROADCASTER_USER_ID,
            "from_broadcaster_user_login": BROADCASTER_USER_LOGIN,
            "from_broadcaster_user_name": BROADCASTER_USER_NAME,
            **_prefixed("to_broadcaster", to_broadcaster_user_name),
            "viewers": viewers,
        },
    )


def cheer(user_name: str | None, bits: int, message: str = "") -> dict:
    return notification(
        "channel.cheer",
        {
            "is_anonymous": user_name is None,
            **_user(user_name),
            **_broadcaster(),
            "message": message,
            "bits": bits,
        },
    )


def _hype_train(level: int, progress: int, goal: int) -> dict:
    return {
        "id": str(uuid.uuid4()),
        **_broadcaster(),
        "level": level,
        "total": progress,
        "progress": progress,
        "goal": goal,
        "top_contributions": [],
        "started_at": timestamp(),
        "expires_at": timestamp(300),
    }


def hype_train_begin(level: int, progress: int, goal: int) -> dict:
    return notification("channel.hype_train.begin", _hype_train(level, progress, goal))


def hype_train_progress(level: int, progress: int, goal: int) -> dict:
    return notification("channel.hype_train.progress", _hype_train(level, progress, goal))


def hype_train_end(level: int) -> dict:
    event = _hype_train(level, 1, 1)
    del event["expires_at"]
    event["ended_at"] = timestamp()
    event["cooldown_ends_at"] = timestamp(3600)
    return notification("channel.hype_train.end", event)


def ad_break_begin(duration_seconds: int, is_automatic: bool) -> dict:
    return notification(
        "channel.ad_break.begin",
        {
            "duration_seconds": duration_seconds,
            "started_at": timestamp(),
            "is_automatic": is_automatic,
            **_broadcaster(),
            "requester_user_id": BROADCASTER_USER_ID,
            "requester_user_login": BROADCASTER_USER_LOGIN,
            "requester_user_name": BROADCASTER_USER_NAME,
        },
    )


def _moderate(action: str, **fields) -> dict:
    return notification(
        "channel.moderate",
        {
            **_broadcaster(),
            "source_broadcaster_user_id": None,
            "source_broadcaster_user_login": None,
            "source_broadcaster_user_name": None,
            "moderator_user_id": BROADCASTER_USER_ID,
            "moderator_user_login": BROADCASTER_USER_LOGIN,
            "moderator_user_name": BROADCASTER_USER_NAME,
            "action": action,
            **fields,
        },
        version="2",
    )


def moderate_raid(user_name: str, viewer_count: int) -> dict:
    return _moderate("raid", raid={**_user(user_name), "viewer_count": viewer_count})


def moderate_unraid(user_name: str) -> dict:
    return _moderate("unraid", unraid=_user(user_name))


def _poll(poll_id: str, title: str, choices: Sequence[tuple[str, int | None]], **fields) -> dict:
    return {
        "id": poll_id,
        **_broadcaster(),
        "title": title,
        "choices": [
            {
                "id": f"{poll_id}-{index}",
                "title": choice_title,
                "bits_votes": 0,
                "channel_points_votes": votes or 0,
                "votes": votes,
            }
            for index, (choice_title, votes) in enumerate(choices)
        ],
        "bits_voting": {"is_enabled": False, "amount_per_vote": 0},
        "channel_points_voting": {"is_enabled": True, "amount_per_vote": 10},
        "started_at": timestamp(),
        **fields,
    }


def poll_begin(poll_id: str, title: str, choices: list[str], ends_in: float = 60) -> dict:
    return notification(
        "channel.poll.begin",
        _poll(poll_id, title, [(choice, None) for choice in choices], ends_at=timestamp(ends_in)),
    )


def poll_progress(poll_id: str, title: str, choices: list[tuple[str, int]], ends_in: float = 60) -> dict:
    return notification("channel.poll.progress", _poll(poll_id, title, choices, ends_at=timestamp(ends_in)))


def poll_end(poll_id: str, title: str, choices: list[tuple[str, int]], status: str = "completed") -> dict:
    return notification(
        "channel.poll.end",
        _poll(poll_id, title, choices, status=status, ended_at=timestamp()),
    )


def _prediction(
    prediction_id: str,
    title: str,
    outcomes: list[tuple[str, int, int]],
    **fields,
) -> dict:
    return {
        "id": prediction_id,
        **_broadcaster(),
        "title": title,
        "outcomes": [
            {
                "id": f"{prediction_id}-{index}",
                "title": outcome_title,
                "color": ["blue", "pink"][index % 2],
                "users": users,
                "channel_points": channel_points,
                "top_predictors": [],
            }
            for index, (outcome_title, users, channel_points) in enumerate(outcomes)
        ],
        "started_at": timestamp(),
        **fields,
    }


def prediction_begin(prediction_id: str, title: str, outcomes: list[str], locks_in: float = 60) -> dict:
    return notification(
        "channel.prediction.begin",
        _prediction(
            prediction_id,
            title,
            [(outcome, 0, 0) for outcome in outcomes],
            locks_at=timestamp(locks_in),
        ),
    )


def prediction_progress(
    prediction_id: str,
    title: str,
    outcomes: list[tuple[str, int, int]],
    locks_in: float = 60,
) -> dict:
    return notification(
        "channel.prediction.progress",
        _prediction(prediction_id, title, outcomes, locks_at=timestamp(locks_in)),
    )


def prediction_lock(prediction_id: str, title: str, outcomes: list[tuple[str, int, int]]) -> dict:
    return notification(
        "channel.prediction.lock",
        _prediction(prediction_id, title, outcomes, locked_at=timestamp()),
    )


def prediction_end(
    prediction_id: str,
    title: str,
    outcomes: list[tuple[str, int, int]],
    winning_outcome_index: int | None,
) -> dict:
    if winning_outcome_index is None:
        winning_outcome_id = None
        status = "canceled"
    else:
        winning_outcome_id = f"{prediction_id}-{winning_outcome_index}"
        status = "resolved"
    return notification(
        "channel.prediction.end",
        _prediction(
            prediction_id,
            title,
            outcomes,
            winning_outcome_id=winning_outcome_id,
            status=status,
            ended_at=timestamp(),
        ),
    )
