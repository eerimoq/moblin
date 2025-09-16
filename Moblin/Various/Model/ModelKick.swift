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

    private func createKickApi() -> KickApi? {
        guard let channelId = stream.kickChannelId, let slug = stream.kickSlug else {
            return nil
        }
        return KickApi(channelId: channelId, slug: slug, accessToken: stream.kickAccessToken)
    }

    func makeNotLoggedInToKickToast() {
        makeErrorToast(
            title: String(localized: "Not logged in to Kick"),
            subTitle: String(localized: "Please login again")
        )
    }

    func sendKickChatMessage(message: String) {
        createKickApi()?.sendMessage(message: message)
    }

    func banKickUser(user: String, duration: Int? = nil) {
        createKickApi()?.banUser(user: user, duration: duration)
    }

    func deleteKickMessage(messageId: String) {
        createKickApi()?.deleteMessage(messageId: messageId)
    }

    func getKickStreamTitle(onComplete: @escaping (String) -> Void) {
        createKickApi()?.getStreamTitle(onComplete: onComplete)
    }

    func setKickStreamTitle(title: String, onComplete: @escaping (String) -> Void) {
        createKickApi()?.setStreamTitle(title: title, onComplete: onComplete)
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

    func kickPusherSubscription(event: SubscriptionEvent) {
        DispatchQueue.main.async {
            let text = String(localized: "just subscribed! They've been subscribed for \(event.months) months!")
            self.makeToast(title: "🎉 \(event.username) \(text)")
            self.appendKickChatAlertMessage(
                user: event.username,
                text: text,
                title: String(localized: "New subscriber"),
                color: .cyan,
                image: "party.popper"
            )
        }
    }

    func kickPusherGiftedSubscription(event: GiftedSubscriptionsEvent) {
        DispatchQueue.main.async {
            let user = event.gifter_username
            let text =
                String(localized: """
                just gifted \(event.gifted_usernames.count) subscription(s)! \
                They've gifted \(event.gifter_total) in total!
                """)
            self.makeToast(title: "🎁 \(user) \(text)")
            self.appendKickChatAlertMessage(
                user: user,
                text: text,
                title: String(localized: "Gift subscriptions"),
                color: .cyan,
                image: "gift"
            )
        }
    }

    func kickPusherRewardRedeemed(event: RewardRedeemedEvent) {
        DispatchQueue.main.async {
            let user = event.username
            let baseText = String(localized: "redeemed \(event.reward_title)")
            let text = event.user_input.isEmpty ? baseText : "\(baseText): \(event.user_input)"
            self.makeToast(title: "🎁 \(user) \(text)")
            self.appendKickChatAlertMessage(
                user: user,
                text: text,
                title: String(localized: "Reward Redeemed"),
                color: .green,
                image: "medal.star"
            )
        }
    }

    func kickPusherStreamHost(event: StreamHostEvent) {
        DispatchQueue.main.async {
            let user = event.host_username
            let text = String(localized: "is now hosting with \(event.number_viewers) viewers!")
            self.makeToast(title: "📺 \(user) \(text)")
            self.appendKickChatAlertMessage(
                user: user,
                text: text,
                title: String(localized: "Host"),
                color: .orange,
                image: "person.3"
            )
        }
    }

    func kickPusherUserBanned(event: UserBannedEvent) {
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
            self.makeToast(title: "🚫 \(event.user.username) \(text)")
            self.appendKickChatAlertMessage(
                user: event.user.username,
                text: text,
                title: title,
                color: .red,
                image: "nosign"
            )
        }
    }

    func kickPusherKicksGifted(event: KicksGiftedEvent) {
        DispatchQueue.main.async {
            let user = event.sender.username
            let amount = countFormatter.format(event.gift.amount)
            let text = String(localized: "sent \(event.gift.name) 💎 \(amount)")
            let message = event.message.isEmpty ? text : "\(text) \(event.message)"
            self.makeToast(title: "\(user) \(message)")
            self.appendKickChatAlertMessage(
                user: user,
                text: message,
                title: String(localized: "Kicks"),
                color: .green,
                image: "suit.diamond"
            )
        }
    }
}
