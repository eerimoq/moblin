import Foundation
@testable import Moblin
import Testing

private final class Delegate: TwitchEventSubDelegate {
    var subscribes: [TwitchEventSubNotificationChannelSubscribeEvent] = []
    var resubscribes: [TwitchEventSubNotificationChannelSubscriptionMessageEvent] = []
    var gifts: [TwitchEventSubNotificationChannelSubscriptionGiftEvent] = []
    var upgrades: [TwitchEventSubNotificationChannelSubscriptionUpgradeEvent] = []
    var raids: [TwitchEventSubChannelRaidEvent] = []

    func twitchEventSubChannelFollow(event _: TwitchEventSubNotificationChannelFollowEvent) {}

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

    func twitchEventSubChannelWatchStreak(event _: TwitchEventSubNotificationChannelWatchStreakEvent) {}

    func twitchEventSubChannelPointsCustomRewardRedemptionAdd(
        event _: TwitchEventSubNotificationChannelPointsCustomRewardRedemptionAddEvent
    ) {}

    func twitchEventSubChannelRaid(event: TwitchEventSubChannelRaidEvent) {
        raids.append(event)
    }

    func twitchEventSubChannelCheer(event _: TwitchEventSubChannelCheerEvent) {}
    func twitchEventSubChannelHypeTrainBegin(event _: TwitchEventSubChannelHypeTrainBeginEvent) {}
    func twitchEventSubChannelHypeTrainProgress(event _: TwitchEventSubChannelHypeTrainProgressEvent) {}
    func twitchEventSubChannelHypeTrainEnd(event _: TwitchEventSubChannelHypeTrainEndEvent) {}
    func twitchEventSubChannelAdBreakBegin(event _: TwitchEventSubChannelAdBreakBeginEvent) {}
    func twitchEventSubChannelModerate(event _: TwitchEventSubChannelModerateEvent) {}
    func twitchEventSubUnauthorized() {}
    func twitchEventSubNotification(message _: String) {}
}

private func chatNotification(noticeType: String, shared: Bool, payload: String) -> String {
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
          "chatter_user_name": "Viewer",
          "chatter_is_anonymous": false,
          "color": "",
          "badges": [],
          "system_message": "",
          "message_id": "m",
          "message": {"text": "hello", "fragments": []},
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

private func makeEventSub(delegate: Delegate) -> TwitchEventSub {
    TwitchEventSub(remoteControl: true, userId: "111", accessToken: "", delegate: delegate)
}

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
        #expect(delegate.raids.first?.sharedChat?.broadcasterUserId == "222")
    }
}
