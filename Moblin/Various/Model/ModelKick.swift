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

private struct CachedKickChannelInfo {
    let channelInfo: KickChannel
    let timestamp: Date
    let channelName: String
    static let cacheTimeout: TimeInterval = 300
    func isValid(for channelName: String) -> Bool {
        return self.channelName == channelName &&
            Date().timeIntervalSince(timestamp) < Self.cacheTimeout
    }
}

private var kickChannelInfoCache: CachedKickChannelInfo?
extension Model {
    func isKickPusherConfigured() -> Bool {
        return database.chat.enabled && (stream.kickChatroomId != "" || stream.kickChannelName != "")
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
        if isKickPusherConfigured(), !isChatRemoteControl() {
            kickPusher = KickPusher(delegate: self,
                                    channelId: stream.kickChatroomId,
                                    channelName: stream.kickChannelName,
                                    settings: stream.chat)
            kickPusher!.start()
        }
        updateChatMoreThanOneChatConfigured()
    }

    func kickChannelNameUpdated() {
        reloadKickPusher()
        reloadKickViewers()
        resetChat()
    }

    private func createRequest(url: URL, method: String = "POST") -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(stream.kickAccessToken)", forHTTPHeaderField: "Authorization")
        return request
    }

    func sendKickChatMessage(message: String) {
        getKickChannelInfo(channelName: stream.kickChannelName) { channelInfo in
            guard let channelInfo,
                  let url = URL(string: "https://kick.com/api/v2/messages/send/\(channelInfo.chatroom.id)")
            else {
                return
            }
            var request = self.createRequest(url: url)
            let body = ["type": "message", "content": message]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            URLSession.shared.dataTask(with: request) { _, _, _ in
            }
            .resume()
        }
    }

    func banKickUser(user: String, duration: Int? = nil) {
        getKickChannelInfo(channelName: stream.kickChannelName) { channelInfo in
            guard let slug = channelInfo?.slug,
                  let url = URL(string: "https://kick.com/api/v2/channels/\(slug)/bans")
            else {
                return
            }
            var request = self.createRequest(url: url)
            var body: [String: Any] = [
                "banned_username": user,
                "permanent": duration == nil,
            ]
            if let duration {
                body["duration"] = duration / 60
            }
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            URLSession.shared.dataTask(with: request) { _, response, error in
                DispatchQueue.main.async {
                    let ok = error == nil && response?.http?.isSuccessful == true
                    self.showUserBannedToast(ok: ok, user: user, duration: duration)
                }
            }
            .resume()
        }
    }

    func deleteKickMessage(messageId: String) {
        getKickChannelInfo(channelName: stream.kickChannelName) { channelInfo in
            guard let channelInfo,
                  let url =
                  URL(string: "https://kick.com/api/v2/chatrooms/\(channelInfo.chatroom.id)/messages/\(messageId)")
            else {
                return
            }
            let request = self.createRequest(url: url, method: "DELETE")
            URLSession.shared.dataTask(with: request) { _, response, error in
                DispatchQueue.main.async {
                    let ok = error == nil && response?.http?.isSuccessful == true
                    self.showChatMessageDeletedToast(ok: ok)
                }
            }
            .resume()
        }
    }

    private func makeKickStreamInfoUrl(slug: String) -> URL? {
        return URL(string: "https://kick.com/api/v2/channels/\(slug)/stream-info")
    }

    func getKickStreamTitle(onCompleted: @escaping (String) -> Void) {
        getKickChannelInfo(channelName: stream.kickChannelName) { channelInfo in
            guard let channelInfo, let url = self.makeKickStreamInfoUrl(slug: channelInfo.slug) else {
                return
            }
            let request = self.createRequest(url: url, method: "GET")
            URLSession.shared.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    guard let data,
                          error == nil,
                          response?.http?.isSuccessful == true,
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let streamTitle = json["stream_title"] as? String
                    else {
                        return
                    }
                    onCompleted(streamTitle)
                }
            }
            .resume()
        }
    }

    func setKickStreamTitle(title: String, onCompleted: @escaping (String) -> Void) {
        getKickChannelInfo(channelName: stream.kickChannelName) { channelInfo in
            guard let channelInfo, let url = self.makeKickStreamInfoUrl(slug: channelInfo.slug) else {
                return
            }
            var request = self.createRequest(url: url, method: "PATCH")
            request.httpBody = try? JSONSerialization.data(withJSONObject: ["stream_title": title])
            URLSession.shared.dataTask(with: request) { _, response, error in
                DispatchQueue.main.async {
                    if error == nil, response?.http?.isSuccessful == true {
                        onCompleted(title)
                    }
                }
            }
            .resume()
        }
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

extension Model: KickOusherDelegate {
    func kickPusherMakeErrorToast(title: String, subTitle: String?) {
        makeErrorToast(title: title, subTitle: subTitle)
    }

    func kickPusherAppendMessage(
        messageId: String?,
        user: String,
        userId: String?,
        userColor: RgbColor?,
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
                          userBadges: [],
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
}
