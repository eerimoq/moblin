import Foundation
@testable import Moblin
import Testing

@MainActor
private final class Delegate: TwitchEventSubDelegate {
    var follows: [TwitchEventSubNotificationChannelFollowEvent] = []
    var subscribes: [TwitchEventSubNotificationChannelSubscribeEvent] = []
    var resubscribes: [TwitchEventSubNotificationChannelSubscriptionMessageEvent] = []
    var gifts: [TwitchEventSubNotificationChannelSubscriptionGiftEvent] = []
    var upgrades: [TwitchEventSubNotificationChannelSubscriptionUpgradeEvent] = []
    var watchStreaks: [TwitchEventSubNotificationChannelWatchStreakEvent] = []
    var redemptions: [TwitchEventSubNotificationChannelPointsCustomRewardRedemptionAddEvent] = []
    var raids: [TwitchEventSubChannelRaidEvent] = []
    var cheers: [TwitchEventSubChannelCheerEvent] = []
    var hypeTrainBegins: [TwitchEventSubChannelHypeTrainBeginEvent] = []
    var hypeTrainProgresses: [TwitchEventSubChannelHypeTrainProgressEvent] = []
    var hypeTrainEnds: [TwitchEventSubChannelHypeTrainEndEvent] = []
    var adBreaks: [TwitchEventSubChannelAdBreakBeginEvent] = []
    var polls: [(phase: String, event: TwitchEventSubChannelPollEvent)] = []
    var predictions: [(phase: String, event: TwitchEventSubChannelPredictionEvent)] = []
    var moderates: [TwitchEventSubChannelModerateEvent] = []
    var unauthorizedCount = 0
    var notifications: [String] = []

    func twitchEventSubChannelFollow(event: TwitchEventSubNotificationChannelFollowEvent) {
        follows.append(event)
    }

    func twitchEventSubChannelSubscribe(event: TwitchEventSubNotificationChannelSubscribeEvent) {
        subscribes.append(event)
    }

    func twitchEventSubChannelSubscriptionGift(event: TwitchEventSubNotificationChannelSubscriptionGiftEvent) {
        gifts.append(event)
    }

    func twitchEventSubChannelSubscriptionMessage(
        event: TwitchEventSubNotificationChannelSubscriptionMessageEvent
    ) {
        resubscribes.append(event)
    }

    func twitchEventSubChannelSubscriptionUpgrade(
        event: TwitchEventSubNotificationChannelSubscriptionUpgradeEvent
    ) {
        upgrades.append(event)
    }

    func twitchEventSubChannelWatchStreak(event: TwitchEventSubNotificationChannelWatchStreakEvent) {
        watchStreaks.append(event)
    }

    func twitchEventSubChannelPointsCustomRewardRedemptionAdd(
        event: TwitchEventSubNotificationChannelPointsCustomRewardRedemptionAddEvent
    ) {
        redemptions.append(event)
    }

    func twitchEventSubChannelRaid(event: TwitchEventSubChannelRaidEvent) {
        raids.append(event)
    }

    func twitchEventSubChannelCheer(event: TwitchEventSubChannelCheerEvent) {
        cheers.append(event)
    }

    func twitchEventSubChannelHypeTrainBegin(event: TwitchEventSubChannelHypeTrainBeginEvent) {
        hypeTrainBegins.append(event)
    }

    func twitchEventSubChannelHypeTrainProgress(event: TwitchEventSubChannelHypeTrainProgressEvent) {
        hypeTrainProgresses.append(event)
    }

    func twitchEventSubChannelHypeTrainEnd(event: TwitchEventSubChannelHypeTrainEndEvent) {
        hypeTrainEnds.append(event)
    }

    func twitchEventSubChannelAdBreakBegin(event: TwitchEventSubChannelAdBreakBeginEvent) {
        adBreaks.append(event)
    }

    func twitchEventSubChannelPollBegin(event: TwitchEventSubChannelPollEvent) {
        polls.append((phase: "begin", event: event))
    }

    func twitchEventSubChannelPollProgress(event: TwitchEventSubChannelPollEvent) {
        polls.append((phase: "progress", event: event))
    }

    func twitchEventSubChannelPollEnd(event: TwitchEventSubChannelPollEvent) {
        polls.append((phase: "end", event: event))
    }

    func twitchEventSubChannelPredictionBegin(event: TwitchEventSubChannelPredictionEvent) {
        predictions.append((phase: "begin", event: event))
    }

    func twitchEventSubChannelPredictionProgress(event: TwitchEventSubChannelPredictionEvent) {
        predictions.append((phase: "progress", event: event))
    }

    func twitchEventSubChannelPredictionLock(event: TwitchEventSubChannelPredictionEvent) {
        predictions.append((phase: "lock", event: event))
    }

    func twitchEventSubChannelPredictionEnd(event: TwitchEventSubChannelPredictionEvent) {
        predictions.append((phase: "end", event: event))
    }

    func twitchEventSubChannelModerate(event: TwitchEventSubChannelModerateEvent) {
        moderates.append(event)
    }

    func twitchEventSubUnauthorized() {
        unauthorizedCount += 1
    }

    func twitchEventSubNotification(message: String) {
        notifications.append(message)
    }
}

private func notification(subscriptionType: String, event: String) -> String {
    """
    {
      "metadata": {
        "message_id": "1",
        "message_type": "notification",
        "message_timestamp": "2026-09-06T10:00:00.000Z",
        "subscription_type": "\(subscriptionType)",
        "subscription_version": "1"
      },
      "payload": {
        "subscription": {"id": "s", "type": "\(subscriptionType)"},
        "event": \(event)
      }
    }
    """
}

private func chatNotification(
    noticeType: String,
    shared: Bool,
    payload: String,
    message: String = #"{"text": "hello", "fragments": []}"#,
    chatterUserName: String = "\"Viewer\"",
    chatterIsAnonymous: Bool = false,
    color: String = "",
    badges: String = "[]"
) -> String {
    let payload = payload.isEmpty ? "" : "\(payload),"
    let source = shared ? """
    "source_broadcaster_user_id": "222",
    "source_broadcaster_user_name": "Partner",
    "source_broadcaster_user_login": "partner",
    """ : """
    "source_broadcaster_user_id": null,
    "source_broadcaster_user_name": null,
    "source_broadcaster_user_login": null,
    """
    return """
    {
      "metadata": {
        "message_id": "1",
        "message_type": "notification",
        "message_timestamp": "2026-09-06T10:00:00.000Z",
        "subscription_type": "channel.chat.notification",
        "subscription_version": "1"
      },
      "payload": {
        "subscription": {"id": "s", "type": "channel.chat.notification"},
        "event": {
          "broadcaster_user_id": "111",
          "broadcaster_user_login": "me",
          "broadcaster_user_name": "Me",
          \(source)
          \(payload)
          "chatter_user_id": "333",
          "chatter_user_login": "viewer",
          "chatter_user_name": \(chatterUserName),
          "chatter_is_anonymous": \(chatterIsAnonymous),
          "color": "\(color)",
          "badges": \(badges),
          "system_message": "",
          "message_id": "m",
          "message": \(message),
          "notice_type": "\(noticeType)",
          "sub": null,
          "resub": null,
          "sub_gift": null,
          "community_sub_gift": null,
          "gift_paid_upgrade": null,
          "prime_paid_upgrade": null,
          "raid": null,
          "shared_chat_sub": null,
          "shared_chat_resub": null,
          "shared_chat_sub_gift": null,
          "shared_chat_community_sub_gift": null,
          "shared_chat_gift_paid_upgrade": null,
          "shared_chat_prime_paid_upgrade": null,
          "shared_chat_raid": null
        }
      }
    }
    """
}

@MainActor
private func makeEventSub(delegate: Delegate) -> TwitchEventSub {
    TwitchEventSub(remoteControl: true, userId: "111", accessToken: "", delegate: delegate)
}

@MainActor
struct TwitchEventSubSuite {
    @Test
    func sub() {
        let delegate = Delegate()
        makeEventSub(delegate: delegate).handleMessage(messageText: chatNotification(
            noticeType: "sub",
            shared: false,
            payload: #""sub": {"sub_tier": "1000", "is_prime": false, "duration_months": 1}"#
        ))
        #expect(delegate.subscribes.count == 1)
        #expect(delegate.subscribes.first?.user_name == "Viewer")
        #expect(delegate.subscribes.first?.tierAsNumber() == 1)
        #expect(delegate.subscribes.first?.message?.text == "hello")
        #expect(delegate.subscribes.first?.sharedChat == nil)
    }

    @Test
    func sharedChatSub() {
        let delegate = Delegate()
        makeEventSub(delegate: delegate).handleMessage(messageText: chatNotification(
            noticeType: "shared_chat_sub",
            shared: true,
            payload: #""shared_chat_sub": {"sub_tier": "2000", "is_prime": true, "duration_months": 1}"#
        ))
        #expect(delegate.subscribes.count == 1)
        #expect(delegate.subscribes.first?.user_name == "Viewer")
        #expect(delegate.subscribes.first?.tierAsNumber() == 2)
        #expect(delegate.subscribes.first?.isPrime() == true)
        #expect(delegate.subscribes.first?.sharedChat?.broadcasterUserId == "222")
        #expect(delegate.subscribes.first?.sharedChat?.broadcasterUserName == "Partner")
    }

    @Test
    func sharedChatResub() {
        let delegate = Delegate()
        makeEventSub(delegate: delegate).handleMessage(messageText: chatNotification(
            noticeType: "shared_chat_resub",
            shared: true,
            payload: #"""
            "shared_chat_resub": {
              "cumulative_months": 7,
              "duration_months": 1,
              "streak_months": 3,
              "sub_tier": "1000",
              "is_prime": false,
              "is_gift": false
            }
            """#
        ))
        #expect(delegate.resubscribes.count == 1)
        #expect(delegate.resubscribes.first?.cumulative_months == 7)
        #expect(delegate.resubscribes.first?.streak_months == 3)
        #expect(delegate.resubscribes.first?.message.text == "hello")
        #expect(delegate.resubscribes.first?.sharedChat?.broadcasterUserId == "222")
    }

    @Test
    func resubMessageFragments() {
        let delegate = Delegate()
        makeEventSub(delegate: delegate).handleMessage(messageText: chatNotification(
            noticeType: "resub",
            shared: false,
            payload: #"""
            "resub": {
              "cumulative_months": 2,
              "duration_months": 1,
              "streak_months": null,
              "sub_tier": "1000",
              "is_prime": false,
              "is_gift": false
            }
            """#,
            message: #"""
            {
              "text": "Kappa hi",
              "fragments": [
                {"type": "emote", "text": "Kappa", "cheermote": null,
                 "emote": {"id": "25", "emote_set_id": "0", "owner_id": "0", "format": ["static"]},
                 "mention": null},
                {"type": "text", "text": " hi", "cheermote": null, "emote": null, "mention": null}
              ]
            }
            """#
        ))
        #expect(delegate.resubscribes.count == 1)
        let fragments = delegate.resubscribes.first?.message.fragments ?? []
        #expect(fragments.map(\.type) == ["emote", "text"])
        #expect(fragments.map(\.text) == ["Kappa", " hi"])
        #expect(fragments.map(\.emote?.id) == ["25", nil])
    }

    @Test
    func sharedChatCommunitySubGift() {
        let delegate = Delegate()
        makeEventSub(delegate: delegate).handleMessage(messageText: chatNotification(
            noticeType: "shared_chat_community_sub_gift",
            shared: true,
            payload: #""shared_chat_community_sub_gift": {"id": "g", "total": 5, "sub_tier": "1000"}"#
        ))
        #expect(delegate.gifts.count == 1)
        #expect(delegate.gifts.first?.user_name == "Viewer")
        #expect(delegate.gifts.first?.total == 5)
        #expect(delegate.gifts.first?.message?.text == "hello")
        #expect(delegate.gifts.first?.sharedChat?.broadcasterUserName == "Partner")
    }

    @Test
    func sharedChatSubGiftPartOfCommunityGiftIsIgnored() {
        let delegate = Delegate()
        makeEventSub(delegate: delegate).handleMessage(messageText: chatNotification(
            noticeType: "shared_chat_sub_gift",
            shared: true,
            payload: #"""
            "shared_chat_sub_gift": {
              "duration_months": 1,
              "cumulative_total": 1,
              "recipient_user_id": "4",
              "recipient_user_name": "R",
              "recipient_user_login": "r",
              "sub_tier": "1000",
              "community_gift_id": "g"
            }
            """#
        ))
        #expect(delegate.gifts.isEmpty)
    }

    @Test
    func sharedChatGiftPaidUpgrade() {
        let delegate = Delegate()
        makeEventSub(delegate: delegate).handleMessage(messageText: chatNotification(
            noticeType: "shared_chat_gift_paid_upgrade",
            shared: true,
            payload: #""shared_chat_gift_paid_upgrade": {"gifter_is_anonymous": true}"#
        ))
        #expect(delegate.upgrades.count == 1)
        #expect(delegate.upgrades.first?.tierAsNumber() == nil)
        #expect(delegate.upgrades.first?.message?.text == "hello")
        #expect(delegate.upgrades.first?.sharedChat?.broadcasterUserId == "222")
    }

    @Test
    func sharedChatRaid() {
        let delegate = Delegate()
        makeEventSub(delegate: delegate).handleMessage(messageText: chatNotification(
            noticeType: "shared_chat_raid",
            shared: true,
            payload: #"""
            "shared_chat_raid": {
              "user_id": "555",
              "user_name": "Raider",
              "user_login": "raider",
              "viewer_count": 42,
              "profile_image_url": "https://example.com/raider.png"
            }
            """#
        ))
        #expect(delegate.raids.count == 1)
        #expect(delegate.raids.first?.from_broadcaster_user_id == "555")
        #expect(delegate.raids.first?.from_broadcaster_user_name == "Raider")
        #expect(delegate.raids.first?.viewers == 42)
        #expect(delegate.raids.first?.message?.text == "hello")
        #expect(delegate.raids.first?.sharedChat?.broadcasterUserId == "222")
    }

    @Test
    func invalidJsonIsIgnored() {
        let delegate = Delegate()
        let eventSub = makeEventSub(delegate: delegate)
        eventSub.handleMessage(messageText: "not json")
        eventSub.handleMessage(messageText: "{}")
        eventSub.handleMessage(messageText: #"{"metadata": {}}"#)
        #expect(delegate.notifications.isEmpty)
        #expect(delegate.subscribes.isEmpty)
    }

    @Test
    func keepaliveAndUnknownMessageTypesAreIgnored() {
        let delegate = Delegate()
        let eventSub = makeEventSub(delegate: delegate)
        eventSub.handleMessage(messageText: #"""
        {
          "metadata": {"message_id": "1", "message_type": "session_keepalive"},
          "payload": {}
        }
        """#)
        eventSub.handleMessage(messageText: #"""
        {
          "metadata": {"message_id": "2", "message_type": "revocation", "subscription_type": "channel.follow"},
          "payload": {}
        }
        """#)
        #expect(delegate.notifications.isEmpty)
        #expect(delegate.follows.isEmpty)
    }

    @Test
    func unknownNotificationTypeStillForwardsRawMessage() {
        let delegate = Delegate()
        let message = notification(subscriptionType: "channel.unknown", event: #"{"foo": 1}"#)
        makeEventSub(delegate: delegate).handleMessage(messageText: message)
        #expect(delegate.notifications == [message])
    }

    @Test
    func notificationWithoutSubscriptionTypeStillForwardsRawMessage() {
        let delegate = Delegate()
        let message = #"""
        {
          "metadata": {"message_id": "1", "message_type": "notification"},
          "payload": {}
        }
        """#
        makeEventSub(delegate: delegate).handleMessage(messageText: message)
        #expect(delegate.notifications == [message])
    }

    @Test
    func undecodableNotificationIsDroppedWithoutForwarding() {
        let delegate = Delegate()
        makeEventSub(delegate: delegate).handleMessage(messageText: notification(
            subscriptionType: "channel.follow",
            event: #"{"user_login": "viewer"}"#
        ))
        #expect(delegate.follows.isEmpty)
        #expect(delegate.notifications.isEmpty)
    }

    @Test
    func follow() {
        let delegate = Delegate()
        let message = notification(
            subscriptionType: "channel.follow",
            event: #"""
            {
              "user_id": "333",
              "user_login": "viewer",
              "user_name": "Viewer",
              "broadcaster_user_id": "111",
              "broadcaster_user_login": "me",
              "broadcaster_user_name": "Me",
              "followed_at": "2026-09-06T10:00:00.000Z"
            }
            """#
        )
        makeEventSub(delegate: delegate).handleMessage(messageText: message)
        #expect(delegate.follows.count == 1)
        #expect(delegate.follows.first?.user_name == "Viewer")
        #expect(delegate.notifications == [message])
    }

    @Test
    func channelPointsCustomRewardRedemptionAdd() {
        let delegate = Delegate()
        makeEventSub(delegate: delegate).handleMessage(messageText: notification(
            subscriptionType: "channel.channel_points_custom_reward_redemption.add",
            event: #"""
            {
              "id": "r1",
              "broadcaster_user_id": "111",
              "broadcaster_user_login": "me",
              "broadcaster_user_name": "Me",
              "user_id": "333",
              "user_login": "viewer",
              "user_name": "Viewer",
              "user_input": "hi",
              "status": "unfulfilled",
              "reward": {"id": "rw", "title": "Hydrate", "cost": 500, "prompt": "Drink water"},
              "redeemed_at": "2026-09-06T10:00:00.000Z"
            }
            """#
        ))
        #expect(delegate.redemptions.count == 1)
        #expect(delegate.redemptions.first?.user_name == "Viewer")
        #expect(delegate.redemptions.first?.status == "unfulfilled")
        #expect(delegate.redemptions.first?.reward.title == "Hydrate")
        #expect(delegate.redemptions.first?.reward.cost == 500)
    }

    @Test
    func channelRaid() {
        let delegate = Delegate()
        makeEventSub(delegate: delegate).handleMessage(messageText: notification(
            subscriptionType: "channel.raid",
            event: #"""
            {
              "from_broadcaster_user_id": "555",
              "from_broadcaster_user_login": "raider",
              "from_broadcaster_user_name": "Raider",
              "to_broadcaster_user_id": "111",
              "to_broadcaster_user_login": "me",
              "to_broadcaster_user_name": "Me",
              "viewers": 9001
            }
            """#
        ))
        #expect(delegate.raids.count == 1)
        #expect(delegate.raids.first?.from_broadcaster_user_id == "555")
        #expect(delegate.raids.first?.from_broadcaster_user_name == "Raider")
        #expect(delegate.raids.first?.viewers == 9001)
        #expect(delegate.raids.first?.message == nil)
        #expect(delegate.raids.first?.sharedChat == nil)
    }

    @Test
    func channelCheer() {
        let delegate = Delegate()
        makeEventSub(delegate: delegate).handleMessage(messageText: notification(
            subscriptionType: "channel.cheer",
            event: #"""
            {
              "is_anonymous": false,
              "user_id": "333",
              "user_login": "viewer",
              "user_name": "Viewer",
              "broadcaster_user_id": "111",
              "broadcaster_user_login": "me",
              "broadcaster_user_name": "Me",
              "message": "Cheer100 nice!",
              "bits": 100
            }
            """#
        ))
        #expect(delegate.cheers.count == 1)
        #expect(delegate.cheers.first?.user_name == "Viewer")
        #expect(delegate.cheers.first?.message == "Cheer100 nice!")
        #expect(delegate.cheers.first?.bits == 100)
    }

    @Test
    func anonymousChannelCheer() {
        let delegate = Delegate()
        makeEventSub(delegate: delegate).handleMessage(messageText: notification(
            subscriptionType: "channel.cheer",
            event: #"""
            {
              "is_anonymous": true,
              "user_id": null,
              "user_login": null,
              "user_name": null,
              "broadcaster_user_id": "111",
              "broadcaster_user_login": "me",
              "broadcaster_user_name": "Me",
              "message": "Cheer1",
              "bits": 1
            }
            """#
        ))
        #expect(delegate.cheers.count == 1)
        #expect(delegate.cheers.first?.user_name == nil)
        #expect(delegate.cheers.first?.bits == 1)
    }

    @Test
    func hypeTrain() {
        let delegate = Delegate()
        let eventSub = makeEventSub(delegate: delegate)
        eventSub.handleMessage(messageText: notification(
            subscriptionType: "channel.hype_train.begin",
            event: #"""
            {
              "id": "h",
              "broadcaster_user_id": "111",
              "total": 137,
              "progress": 137,
              "goal": 500,
              "top_contributions": [],
              "last_contribution": {"user_id": "333", "type": "bits", "total": 137},
              "level": 1,
              "started_at": "2026-09-06T10:00:00.000Z",
              "expires_at": "2026-09-06T10:05:00.000Z"
            }
            """#
        ))
        eventSub.handleMessage(messageText: notification(
            subscriptionType: "channel.hype_train.progress",
            event: #"""
            {
              "id": "h",
              "broadcaster_user_id": "111",
              "total": 700,
              "progress": 200,
              "goal": 1000,
              "top_contributions": [],
              "level": 2,
              "started_at": "2026-09-06T10:00:00.000Z",
              "expires_at": "2026-09-06T10:05:00.000Z"
            }
            """#
        ))
        eventSub.handleMessage(messageText: notification(
            subscriptionType: "channel.hype_train.end",
            event: #"""
            {
              "id": "h",
              "broadcaster_user_id": "111",
              "level": 3,
              "total": 1500,
              "top_contributions": [],
              "started_at": "2026-09-06T10:00:00.000Z",
              "ended_at": "2026-09-06T10:05:00.000Z",
              "cooldown_ends_at": "2026-09-06T11:05:00.000Z"
            }
            """#
        ))
        #expect(delegate.hypeTrainBegins.count == 1)
        #expect(delegate.hypeTrainBegins.first?.progress == 137)
        #expect(delegate.hypeTrainBegins.first?.goal == 500)
        #expect(delegate.hypeTrainBegins.first?.level == 1)
        #expect(delegate.hypeTrainProgresses.count == 1)
        #expect(delegate.hypeTrainProgresses.first?.progress == 200)
        #expect(delegate.hypeTrainProgresses.first?.goal == 1000)
        #expect(delegate.hypeTrainProgresses.first?.level == 2)
        #expect(delegate.hypeTrainEnds.count == 1)
        #expect(delegate.hypeTrainEnds.first?.level == 3)
        #expect(delegate.notifications.count == 3)
    }

    @Test
    func adBreakBegin() {
        let delegate = Delegate()
        makeEventSub(delegate: delegate).handleMessage(messageText: notification(
            subscriptionType: "channel.ad_break.begin",
            event: #"""
            {
              "duration_seconds": 60,
              "started_at": "2026-09-06T10:00:00.000Z",
              "is_automatic": false,
              "broadcaster_user_id": "111",
              "broadcaster_user_login": "me",
              "broadcaster_user_name": "Me",
              "requester_user_id": "111",
              "requester_user_login": "me",
              "requester_user_name": "Me"
            }
            """#
        ))
        #expect(delegate.adBreaks.count == 1)
        #expect(delegate.adBreaks.first?.duration_seconds == 60)
        #expect(delegate.adBreaks.first?.is_automatic == false)
    }

    @Test
    func pollBeginProgressEnd() {
        let delegate = Delegate()
        let eventSub = makeEventSub(delegate: delegate)
        eventSub.handleMessage(messageText: notification(
            subscriptionType: "channel.poll.begin",
            event: #"""
            {
              "id": "p",
              "broadcaster_user_id": "111",
              "title": "Pizza?",
              "choices": [{"id": "c1", "title": "Yes"}, {"id": "c2", "title": "No"}],
              "bits_voting": {"is_enabled": false, "amount_per_vote": 0},
              "channel_points_voting": {"is_enabled": false, "amount_per_vote": 0},
              "started_at": "2026-09-06T10:00:00.000Z",
              "ends_at": "2026-09-06T10:05:00.000Z"
            }
            """#
        ))
        eventSub.handleMessage(messageText: notification(
            subscriptionType: "channel.poll.progress",
            event: #"""
            {
              "id": "p",
              "title": "Pizza?",
              "choices": [
                {"id": "c1", "title": "Yes", "bits_votes": 0, "channel_points_votes": 2, "votes": 7},
                {"id": "c2", "title": "No", "bits_votes": 0, "channel_points_votes": 0, "votes": 3}
              ],
              "ends_at": "2026-09-06T10:05:00.000Z"
            }
            """#
        ))
        eventSub.handleMessage(messageText: notification(
            subscriptionType: "channel.poll.end",
            event: #"""
            {
              "id": "p",
              "title": "Pizza?",
              "choices": [
                {"id": "c1", "title": "Yes", "votes": 8},
                {"id": "c2", "title": "No", "votes": 3}
              ],
              "status": "completed",
              "ended_at": "2026-09-06T10:05:00.000Z"
            }
            """#
        ))
        #expect(delegate.polls.map(\.phase) == ["begin", "progress", "end"])
        #expect(delegate.polls.map(\.event.id) == ["p", "p", "p"])
        #expect(delegate.polls[0].event.title == "Pizza?")
        #expect(delegate.polls[0].event.choices.map(\.title) == ["Yes", "No"])
        #expect(delegate.polls[0].event.choices.map(\.votes) == [nil, nil])
        #expect(delegate.polls[0].event.ends_at == "2026-09-06T10:05:00.000Z")
        #expect(delegate.polls[0].event.status == nil)
        #expect(delegate.polls[1].event.choices.map(\.votes) == [7, 3])
        #expect(delegate.polls[2].event.choices.map(\.votes) == [8, 3])
        #expect(delegate.polls[2].event.status == "completed")
        #expect(delegate.polls[2].event.ends_at == nil)
    }

    @Test
    func predictionBeginProgressLockEnd() {
        let delegate = Delegate()
        let eventSub = makeEventSub(delegate: delegate)
        eventSub.handleMessage(messageText: notification(
            subscriptionType: "channel.prediction.begin",
            event: #"""
            {
              "id": "pr",
              "broadcaster_user_id": "111",
              "title": "Win?",
              "outcomes": [
                {"id": "o1", "title": "Yes", "color": "blue"},
                {"id": "o2", "title": "No", "color": "pink"}
              ],
              "started_at": "2026-09-06T10:00:00.000Z",
              "locks_at": "2026-09-06T10:02:00.000Z"
            }
            """#
        ))
        eventSub.handleMessage(messageText: notification(
            subscriptionType: "channel.prediction.progress",
            event: #"""
            {
              "id": "pr",
              "title": "Win?",
              "outcomes": [
                {"id": "o1", "title": "Yes", "color": "blue", "users": 4, "channel_points": 900,
                 "top_predictors": []},
                {"id": "o2", "title": "No", "color": "pink", "users": 1, "channel_points": 100,
                 "top_predictors": []}
              ],
              "locks_at": "2026-09-06T10:02:00.000Z"
            }
            """#
        ))
        eventSub.handleMessage(messageText: notification(
            subscriptionType: "channel.prediction.lock",
            event: #"""
            {
              "id": "pr",
              "title": "Win?",
              "outcomes": [
                {"id": "o1", "title": "Yes", "color": "blue", "users": 5, "channel_points": 1000},
                {"id": "o2", "title": "No", "color": "pink", "users": 1, "channel_points": 100}
              ],
              "locked_at": "2026-09-06T10:02:00.000Z"
            }
            """#
        ))
        eventSub.handleMessage(messageText: notification(
            subscriptionType: "channel.prediction.end",
            event: #"""
            {
              "id": "pr",
              "title": "Win?",
              "winning_outcome_id": "o1",
              "outcomes": [
                {"id": "o1", "title": "Yes", "color": "blue", "users": 5, "channel_points": 1000},
                {"id": "o2", "title": "No", "color": "pink", "users": 1, "channel_points": 100}
              ],
              "status": "resolved",
              "ended_at": "2026-09-06T10:10:00.000Z"
            }
            """#
        ))
        #expect(delegate.predictions.map(\.phase) == ["begin", "progress", "lock", "end"])
        #expect(delegate.predictions[0].event.title == "Win?")
        #expect(delegate.predictions[0].event.outcomes.map(\.color) == ["blue", "pink"])
        #expect(delegate.predictions[0].event.outcomes.map(\.users) == [nil, nil])
        #expect(delegate.predictions[0].event.locks_at == "2026-09-06T10:02:00.000Z")
        #expect(delegate.predictions[0].event.winning_outcome_id == nil)
        #expect(delegate.predictions[1].event.outcomes.map(\.users) == [4, 1])
        #expect(delegate.predictions[1].event.outcomes.map(\.channel_points) == [900, 100])
        #expect(delegate.predictions[2].event.locks_at == nil)
        #expect(delegate.predictions[3].event.winning_outcome_id == "o1")
        #expect(delegate.predictions[3].event.status == "resolved")
    }

    @Test
    func moderateRaid() {
        let delegate = Delegate()
        makeEventSub(delegate: delegate).handleMessage(messageText: notification(
            subscriptionType: "channel.moderate",
            event: #"""
            {
              "broadcaster_user_id": "111",
              "moderator_user_id": "111",
              "action": "raid",
              "raid": {"user_id": "555", "user_login": "target", "user_name": "Target", "viewer_count": 12},
              "unraid": null,
              "ban": null,
              "timeout": null
            }
            """#
        ))
        #expect(delegate.moderates.count == 1)
        #expect(delegate.moderates.first?.action == "raid")
        #expect(delegate.moderates.first?.raid?.user_login == "target")
        #expect(delegate.moderates.first?.raid?.user_name == "Target")
    }

    @Test
    func moderateOtherAction() {
        let delegate = Delegate()
        makeEventSub(delegate: delegate).handleMessage(messageText: notification(
            subscriptionType: "channel.moderate",
            event: #"""
            {
              "broadcaster_user_id": "111",
              "moderator_user_id": "111",
              "action": "ban",
              "raid": null,
              "ban": {"user_id": "666", "user_login": "bad", "user_name": "Bad", "reason": ""}
            }
            """#
        ))
        #expect(delegate.moderates.count == 1)
        #expect(delegate.moderates.first?.action == "ban")
        #expect(delegate.moderates.first?.raid == nil)
    }

    @Test
    func subWithChatterColorAndBadges() {
        let delegate = Delegate()
        makeEventSub(delegate: delegate).handleMessage(messageText: chatNotification(
            noticeType: "sub",
            shared: false,
            payload: #""sub": {"sub_tier": "1000", "is_prime": true, "duration_months": 1}"#,
            color: "#FF0000",
            badges: #"[{"set_id": "subscriber", "id": "12", "info": "12"}, {"set_id": "vip", "id": "1", "info": ""}]"#
        ))
        #expect(delegate.subscribes.count == 1)
        #expect(delegate.subscribes.first?.isPrime() == true)
        #expect(delegate.subscribes.first?.chatter?.color == "#FF0000")
        #expect(delegate.subscribes.first?.chatter?.badges.map(\.set_id) == ["subscriber", "vip"])
        #expect(delegate.subscribes.first?.chatter?.badges.map(\.id) == ["12", "1"])
    }

    @Test
    func subWithMissingPayloadIsIgnored() {
        let delegate = Delegate()
        makeEventSub(delegate: delegate).handleMessage(messageText: chatNotification(
            noticeType: "sub",
            shared: false,
            payload: ""
        ))
        #expect(delegate.subscribes.isEmpty)
        #expect(delegate.notifications.count == 1)
    }

    @Test
    func resub() {
        let delegate = Delegate()
        makeEventSub(delegate: delegate).handleMessage(messageText: chatNotification(
            noticeType: "resub",
            shared: false,
            payload: #"""
            "resub": {
              "cumulative_months": 12,
              "duration_months": 1,
              "streak_months": null,
              "sub_tier": "3000",
              "is_prime": false,
              "is_gift": false
            }
            """#
        ))
        #expect(delegate.resubscribes.count == 1)
        #expect(delegate.resubscribes.first?.user_name == "Viewer")
        #expect(delegate.resubscribes.first?.cumulative_months == 12)
        #expect(delegate.resubscribes.first?.streak_months == nil)
        #expect(delegate.resubscribes.first?.tierAsNumber() == 3)
        #expect(delegate.resubscribes.first?.sharedChat == nil)
    }

    @Test
    func subGift() {
        let delegate = Delegate()
        makeEventSub(delegate: delegate).handleMessage(messageText: chatNotification(
            noticeType: "sub_gift",
            shared: false,
            payload: #"""
            "sub_gift": {
              "duration_months": 3,
              "cumulative_total": 5,
              "recipient_user_id": "4",
              "recipient_user_name": "R",
              "recipient_user_login": "r",
              "sub_tier": "2000",
              "community_gift_id": null
            }
            """#
        ))
        #expect(delegate.gifts.count == 1)
        #expect(delegate.gifts.first?.user_name == "Viewer")
        #expect(delegate.gifts.first?.total == 1)
        #expect(delegate.gifts.first?.tierAsNumber() == 2)
        #expect(delegate.gifts.first?.sharedChat == nil)
    }

    @Test
    func subGiftPartOfCommunityGiftIsIgnored() {
        let delegate = Delegate()
        makeEventSub(delegate: delegate).handleMessage(messageText: chatNotification(
            noticeType: "sub_gift",
            shared: false,
            payload: #"""
            "sub_gift": {
              "duration_months": 1,
              "cumulative_total": 1,
              "recipient_user_id": "4",
              "recipient_user_name": "R",
              "recipient_user_login": "r",
              "sub_tier": "1000",
              "community_gift_id": "g"
            }
            """#
        ))
        #expect(delegate.gifts.isEmpty)
    }

    @Test
    func communitySubGift() {
        let delegate = Delegate()
        makeEventSub(delegate: delegate).handleMessage(messageText: chatNotification(
            noticeType: "community_sub_gift",
            shared: false,
            payload: #""community_sub_gift": {"id": "g", "total": 20, "sub_tier": "3000", "cumulative_total": 40}"#
        ))
        #expect(delegate.gifts.count == 1)
        #expect(delegate.gifts.first?.user_name == "Viewer")
        #expect(delegate.gifts.first?.total == 20)
        #expect(delegate.gifts.first?.tierAsNumber() == 3)
    }

    @Test
    func anonymousCommunitySubGift() {
        let delegate = Delegate()
        makeEventSub(delegate: delegate).handleMessage(messageText: chatNotification(
            noticeType: "community_sub_gift",
            shared: false,
            payload: #""community_sub_gift": {"id": "g", "total": 5, "sub_tier": "1000", "cumulative_total": null}"#,
            chatterUserName: "null",
            chatterIsAnonymous: true,
            badges: #"[{"set_id": "vip", "id": "1", "info": ""}]"#
        ))
        #expect(delegate.gifts.count == 1)
        #expect(delegate.gifts.first?.user_name == nil)
        #expect(delegate.gifts.first?.total == 5)
        #expect(delegate.gifts.first?.chatter == nil)
    }

    @Test
    func anonymousSubHasEmptyUserName() {
        let delegate = Delegate()
        makeEventSub(delegate: delegate).handleMessage(messageText: chatNotification(
            noticeType: "sub",
            shared: false,
            payload: #""sub": {"sub_tier": "1000", "is_prime": false, "duration_months": 1}"#,
            chatterUserName: "null",
            chatterIsAnonymous: true
        ))
        #expect(delegate.subscribes.count == 1)
        #expect(delegate.subscribes.first?.user_name == "")
        #expect(delegate.subscribes.first?.chatter == nil)
    }

    @Test
    func primePaidUpgrade() {
        let delegate = Delegate()
        makeEventSub(delegate: delegate).handleMessage(messageText: chatNotification(
            noticeType: "prime_paid_upgrade",
            shared: false,
            payload: #""prime_paid_upgrade": {"sub_tier": "2000"}"#
        ))
        #expect(delegate.upgrades.count == 1)
        #expect(delegate.upgrades.first?.user_name == "Viewer")
        #expect(delegate.upgrades.first?.tierAsNumber() == 2)
        #expect(delegate.upgrades.first?.message?.text == "hello")
        #expect(delegate.upgrades.first?.sharedChat == nil)
    }

    @Test
    func sharedChatPrimePaidUpgrade() {
        let delegate = Delegate()
        makeEventSub(delegate: delegate).handleMessage(messageText: chatNotification(
            noticeType: "shared_chat_prime_paid_upgrade",
            shared: true,
            payload: #""shared_chat_prime_paid_upgrade": {"sub_tier": "1000"}"#
        ))
        #expect(delegate.upgrades.count == 1)
        #expect(delegate.upgrades.first?.tierAsNumber() == 1)
        #expect(delegate.upgrades.first?.sharedChat?.broadcasterUserName == "Partner")
    }

    @Test
    func giftPaidUpgrade() {
        let delegate = Delegate()
        makeEventSub(delegate: delegate).handleMessage(messageText: chatNotification(
            noticeType: "gift_paid_upgrade",
            shared: false,
            payload: #"""
            "gift_paid_upgrade": {
              "gifter_is_anonymous": false,
              "gifter_user_id": "9",
              "gifter_user_name": "G",
              "gifter_user_login": "g"
            }
            """#
        ))
        #expect(delegate.upgrades.count == 1)
        #expect(delegate.upgrades.first?.user_name == "Viewer")
        #expect(delegate.upgrades.first?.tier == nil)
        #expect(delegate.upgrades.first?.tierAsNumber() == nil)
    }

    @Test
    func watchStreak() {
        let delegate = Delegate()
        makeEventSub(delegate: delegate).handleMessage(messageText: chatNotification(
            noticeType: "watch_streak",
            shared: false,
            payload: #""watch_streak": {"streak_count": 25}"#,
            message: #"{"text": "streak!", "fragments": []}"#
        ))
        #expect(delegate.watchStreaks.count == 1)
        #expect(delegate.watchStreaks.first?.user_name == "Viewer")
        #expect(delegate.watchStreaks.first?.streak_count == 25)
        #expect(delegate.watchStreaks.first?.message.text == "streak!")
        #expect(delegate.watchStreaks.first?.chatter?.color == "")
    }

    @Test
    func unknownNoticeTypeIsIgnored() {
        let delegate = Delegate()
        let message = chatNotification(
            noticeType: "announcement",
            shared: false,
            payload: #""announcement": {"color": "PRIMARY"}"#
        )
        makeEventSub(delegate: delegate).handleMessage(messageText: message)
        #expect(delegate.subscribes.isEmpty)
        #expect(delegate.resubscribes.isEmpty)
        #expect(delegate.gifts.isEmpty)
        #expect(delegate.upgrades.isEmpty)
        #expect(delegate.raids.isEmpty)
        #expect(delegate.watchStreaks.isEmpty)
        #expect(delegate.notifications == [message])
    }

    @Test
    func sharedChatSourceRequiresBothIdAndName() {
        let delegate = Delegate()
        makeEventSub(delegate: delegate).handleMessage(messageText: chatNotification(
            noticeType: "sub",
            shared: false,
            payload: #""sub": {"sub_tier": "1000", "is_prime": false, "duration_months": 1}"#
        ).replacingOccurrences(of: #""source_broadcaster_user_id": null"#,
                               with: #""source_broadcaster_user_id": "222""#))
        #expect(delegate.subscribes.count == 1)
        #expect(delegate.subscribes.first?.sharedChat == nil)
    }
}
