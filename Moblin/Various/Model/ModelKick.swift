import Foundation
import SwiftUI

private enum KickSendError: Error {
    case notLoggedIn
    case channelNotSet
    case channelInfoFailed
    case invalidURL
    case invalidResponse
    case httpError(Int)
}

extension Model {
    func isKickPusherConfigured() -> Bool {
        return database.chat.enabled && stream.kickChannelName != ""
    }

    func isKickPusherConnected() -> Bool {
        return kickPusher?.isConnected() ?? false
    }

    func hasKickPusherEmotes() -> Bool {
        return kickPusher?.hasEmotes() ?? false
    }

    func isKickViewersConfigured() -> Bool {
        return stream.kickChannelName != ""
    }

    func reloadKickViewers() {
        kickViewers?.stop()
        if isKickViewersConfigured() {
            kickViewers = KickViewers()
            kickViewers!.start(channelName: stream.kickChannelName)
        }
    }

    func reloadKickPusher() {
        kickPusher?.stop()
        kickPusher = nil
        setTextToSpeechStreamerMentions()
        if isKickPusherConfigured(),
           !isChatRemoteControl(),
           let channelId = stream.kickChannelId,
           let chatroomChannelId = stream.kickChatroomChannelId
        {
            kickPusher = KickPusher(
                delegate: self,
                channelName: stream.kickChannelName,
                channelId: channelId,
                chatroomChannelId: chatroomChannelId,
                settings: stream.chat
            )
            kickPusher!.start()
        }
        updateChatMoreThanOneChatConfigured()
    }

    func kickChannelNameUpdated() {
        reloadKickPusher()
        reloadKickViewers()
        resetChat()
    }

    func kickAccessTokenUpdated() {
        reloadKickPusher()
        reloadKickViewers()
        resetChat()
    }

    func updateKickChannelInfoIfNeeded() {
        guard !stream.kickChannelName.isEmpty else {
            return
        }
        guard stream.kickChannelId == nil || stream.kickSlug == nil || stream.kickChatroomChannelId == nil else {
            return
        }
        getKickChannelInfo(channelName: stream.kickChannelName) { channelInfo in
            DispatchQueue.main.async {
                if let channelInfo {
                    self.stream.kickChannelId = String(channelInfo.chatroom.id)
                    self.stream.kickSlug = channelInfo.slug
                    self.stream.kickChatroomChannelId = String(channelInfo.chatroom.channel_id)
                }
                self.kickChannelNameUpdated()
            }
        }
    }

    func makeNotLoggedInToKickToast() {
        makeErrorToast(
            title: String(localized: "Not logged in to Kick"),
            subTitle: String(localized: "Please login again")
        )
    }

    func sendKickChatMessage(message: String) {
        createKickApi(stream: stream)?.sendMessage(message: message)
    }

    func banKickUser(user: String, duration: Int? = nil) {
        createKickApi(stream: stream)?.banUser(user: user, duration: duration)
    }

    func deleteKickMessage(messageId: String) {
        createKickApi(stream: stream)?.deleteMessage(messageId: messageId)
    }

    func getKickStreamInfo(stream: SettingsStream, onComplete: @escaping (KickStreamInfo?) -> Void) {
        createKickApi(stream: stream)?.getStreamInfo(onComplete: onComplete)
    }

    func setKickStreamTitle(stream: SettingsStream, title: String, onComplete: @escaping (String) -> Void) {
        createKickApi(stream: stream)?.setStreamTitle(title: title, onComplete: onComplete)
    }

    func searchKickCategories(stream: SettingsStream, query: String, onComplete: @escaping ([KickCategory]?) -> Void) {
        kickSearchCategoriesTimer.startSingleShot(timeout: 0.5) {
            self.createKickApi(stream: stream)?.searchCategories(query: query, onComplete: onComplete)
        }
    }

    func fetchKickCategories(query: String, onComplete: @escaping ([KickCategory]?) -> Void) {
        createKickApi(stream: stream)?.searchCategories(query: query, onComplete: onComplete)
    }

    func setKickStreamCategory(stream: SettingsStream, categoryId: Int) {
        createKickApi(stream: stream)?.setStreamCategory(categoryId: categoryId) { ok in
            if !ok {
                self.makeErrorToast(title: "Failed to set stream category")
            }
        }
    }

    private func createKickApi(stream: SettingsStream) -> KickApi? {
        guard let channelId = stream.kickChannelId, let slug = stream.kickSlug else {
            return nil
        }
        return KickApi(channelId: channelId, slug: slug, accessToken: stream.kickAccessToken)
    }

    private func appendKickChatAlertMessage(
        user: String,
        text: String,
        title: String,
        color: Color,
        image: String? = nil,
        kind: ChatHighlightKind? = nil,
        bits _: String? = nil
    ) {
        var id = 0
        appendChatMessage(platform: .kick,
                          messageId: nil,
                          displayName: user,
                          user: user,
                          userId: nil,
                          userColor: nil,
                          userBadges: [],
                          segments: makeChatPostTextSegments(text: text, id: &id),
                          timestamp: statusOther.digitalClock,
                          timestampTime: .now,
                          isAction: false,
                          isSubscriber: false,
                          isModerator: false,
                          isOwner: false,
                          bits: nil,
                          highlight: .init(
                              kind: kind ?? .redemption,
                              barColor: color,
                              image: image ?? "medal",
                              titleSegments: [ChatPostSegment(id: 0, text: title)]
                          ),
                          live: true)
    }
}

extension Model: KickPusherDelegate {
    func kickPusherMakeErrorToast(title: String, subTitle: String?) {
        makeErrorToast(title: title, subTitle: subTitle)
    }

    func kickPusherAppendMessage(
        messageId: String?,
        user: String,
        userId: String?,
        userColor: RgbColor?,
        userBadges: [URL],
        segments: [ChatPostSegment],
        isSubscriber: Bool,
        isModerator: Bool,
        highlight: ChatHighlight?
    ) {
        appendChatMessage(platform: .kick,
                          messageId: messageId,
                          displayName: user,
                          user: user,
                          userId: userId,
                          userColor: userColor,
                          userBadges: userBadges,
                          segments: segments,
                          timestamp: statusOther.digitalClock,
                          timestampTime: .now,
                          isAction: false,
                          isSubscriber: isSubscriber,
                          isModerator: isModerator,
                          isOwner: false,
                          bits: nil,
                          highlight: highlight,
                          live: true)
    }

    func kickPusherDeleteMessage(messageId: String) {
        deleteChatMessage(messageId: messageId)
    }

    func kickPusherDeleteUser(userId: String) {
        deleteChatUser(userId: userId)
    }

    func kickPusherSubscription(event: KickPusherSubscriptionEvent) {
        let text = String(localized: "just subscribed! They've been subscribed for \(event.months) months!")
        if stream.kickToastAlerts.subscriptions {
            makeToast(title: "🎉 \(event.username) \(text)")
        }
        if stream.kickChatAlerts.subscriptions {
            appendKickChatAlertMessage(
                user: event.username,
                text: text,
                title: String(localized: "New subscriber"),
                color: .cyan,
                image: "party.popper"
            )
        }
        playAlert(alert: .kickSubscription(event: event))
        printEventCatPrinters(event: .kickSubscription, username: event.username, message: text)
    }

    func kickPusherGiftedSubscription(event: KickPusherGiftedSubscriptionsEvent) {
        let user = event.gifter_username
        let text =
            String(localized: """
            just gifted \(event.gifted_usernames.count) subscription(s)! \
            They've gifted \(event.gifter_total) in total!
            """)
        if stream.kickChatAlerts.giftedSubscriptions {
            makeToast(title: "🎁 \(user) \(text)")
        }
        if stream.kickChatAlerts.giftedSubscriptions {
            appendKickChatAlertMessage(
                user: user,
                text: text,
                title: String(localized: "Gift subscriptions"),
                color: .cyan,
                image: "gift"
            )
        }
        playAlert(alert: .kickGiftedSubscriptions(event: event))
        printEventCatPrinters(event: .kickGiftedSubscriptions, username: user, message: text)
    }

    func kickPusherRewardRedeemed(event: KickPusherRewardRedeemedEvent) {
        let user = event.username
        let baseText = String(localized: "redeemed \(event.reward_title)")
        let text = event.user_input.isEmpty ? baseText : "\(baseText): \(event.user_input)"
        if stream.kickToastAlerts.rewards {
            makeToast(title: "🎁 \(user) \(text)")
        }
        if stream.kickChatAlerts.rewards {
            appendKickChatAlertMessage(
                user: user,
                text: text,
                title: String(localized: "Reward Redeemed"),
                color: .green,
                image: "medal.star"
            )
        }
        playAlert(alert: .kickReward(event: event))
        printEventCatPrinters(event: .kickReward, username: user, message: text)
    }

    func kickPusherStreamHost(event: KickPusherStreamHostEvent) {
        let user = event.host_username
        let text = String(localized: "is now hosting with \(event.number_viewers) viewers!")
        if stream.kickToastAlerts.hosts {
            makeToast(title: "📺 \(user) \(text)")
        }
        if stream.kickChatAlerts.hosts {
            appendKickChatAlertMessage(
                user: user,
                text: text,
                title: String(localized: "Host"),
                color: .orange,
                image: "person.3"
            )
        }
        playAlert(alert: .kickHost(event: event))
        printEventCatPrinters(event: .kickHost, username: user, message: text)
    }

    func kickPusherUserBanned(event: KickPusherUserBannedEvent) {
        DispatchQueue.main.async {
            let text: String
            let title: String
            if event.permanent {
                text = String(localized: "was banned from chat!")
                title = String(localized: "User banned")
            } else {
                text = String(localized: "was timed out from chat!")
                title = String(localized: "User timed out")
            }
            if self.stream.kickChatAlerts.bans {
                self.appendKickChatAlertMessage(
                    user: event.user.username,
                    text: text,
                    title: title,
                    color: .red,
                    image: "nosign"
                )
            }
        }
    }

    func kickPusherKicksGifted(event: KickPusherKicksGiftedEvent) {
        let user = event.sender.username
        let amount = countFormatter.format(event.gift.amount)
        let text = String(localized: "sent \(event.gift.name) 💎 \(amount)")
        let message = event.message.isEmpty ? text : "\(text) \(event.message)"
        if stream.kickToastAlerts.isKicksEnabled(amount: event.gift.amount) {
            makeToast(title: "\(user) \(message)")
        }
        if stream.kickChatAlerts.isKicksEnabled(amount: event.gift.amount) {
            appendKickChatAlertMessage(
                user: user,
                text: message,
                title: String(localized: "Kicks"),
                color: .green,
                image: "suit.diamond"
            )
        }
        playAlert(alert: .kickKicks(event: event))
        printEventCatPrinters(event: .kickKicks(amount: event.gift.amount), username: user, message: message)
    }
}
