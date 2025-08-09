import Foundation
import SwiftUI

extension Model {
    func isKickPusherConfigured() -> Bool {
        return database.chat.enabled && (stream.kickChatroomId != "" || stream.kickChannelName != "")
    }

    func isKickLoggedIn() -> Bool {
        return stream.kickLoggedIn && !stream.kickAccessToken.isEmpty
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

    func sendKickChatMessage(message: String) {
        guard isKickLoggedIn() else {
            makeErrorToast(title: "Not logged in to Kick")
            return
        }

        // Get the chatroom ID the same way KickPusher does
        guard !stream.kickChannelName.isEmpty else {
            makeErrorToast(title: "Channel name not set")
            return
        }

        // First get the channel info to get the correct chatroom ID
        getKickChannelInfo(channelName: stream.kickChannelName) { [weak self] channelInfo in
            guard let self = self, let channelInfo = channelInfo else {
                DispatchQueue.main.async {
                    self?.makeErrorToast(title: "Failed to get channel info")
                }
                return
            }

            let chatroomId = channelInfo.chatroom.id
            self.sendKickMessage(chatroomId: chatroomId, message: message)
        }
    }

    private func sendKickMessage(chatroomId: Int, message: String) {
        let url = URL(string: "https://kick.com/api/v2/messages/send/\(chatroomId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(stream.kickAccessToken)", forHTTPHeaderField: "Authorization")

        let body = ["content": message, "type": "message"]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.makeErrorToast(title: "Failed to send message", subTitle: error.localizedDescription)
                    return
                }

                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode != 200 {
                        let statusMessage = HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
                        self.makeErrorToast(
                            title: "Failed to send message",
                            subTitle: "HTTP \(httpResponse.statusCode): \(statusMessage)"
                        )
                        return
                    }
                }

                // Success - no need to show anything as the message will appear in chat via Pusher
            }
        }.resume()
    }

    func banKickUser(user: String, duration: Int? = nil, reason: String = "") {
        guard isKickLoggedIn() else {
            makeErrorToast(title: "Not logged in to Kick")
            return
        }

        guard !stream.kickChannelName.isEmpty else {
            makeErrorToast(title: "Channel name not set")
            return
        }

        // Get channel info to get the slug
        getKickChannelInfo(channelName: stream.kickChannelName) { [weak self] channelInfo in
            guard let self = self, let channelInfo = channelInfo else {
                DispatchQueue.main.async {
                    self?.makeErrorToast(title: "Failed to get channel info")
                }
                return
            }

            let slug = channelInfo.slug
            let url = URL(string: "https://kick.com/api/v2/channels/\(slug)/bans")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(self.stream.kickAccessToken)", forHTTPHeaderField: "Authorization")

            var body: [String: Any] = [
                "banned_username": user,
                "permanent": duration == nil,
            ]

            if !reason.isEmpty {
                body["reason"] = reason
            }

            if let duration = duration {
                // Kick API expects duration in minutes, not seconds
                body["duration"] = duration / 60
            }

            request.httpBody = try? JSONSerialization.data(withJSONObject: body)

            URLSession.shared.dataTask(with: request) { _, response, error in
                DispatchQueue.main.async {
                    if let error = error {
                        self.makeErrorToast(title: "Failed to ban user", subTitle: error.localizedDescription)
                        return
                    }

                    if let httpResponse = response as? HTTPURLResponse {
                        if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                            if let duration = duration {
                                let minutes = duration / 60
                                if minutes < 60 {
                                    let timeText = minutes == 1 ? "1 minute" : "\(minutes) minutes"
                                    self
                                        .makeToast(
                                            title: String(localized: "Successfully timed out \(user) for \(timeText)")
                                        )
                                } else {
                                    let hours = minutes / 60
                                    let timeText = hours == 1 ? "1 hour" : "\(hours) hours"
                                    self
                                        .makeToast(
                                            title: String(localized: "Successfully timed out \(user) for \(timeText)")
                                        )
                                }
                            } else {
                                self.makeToast(title: String(localized: "Successfully banned \(user)"))
                            }
                        } else {
                            let statusMessage = HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
                            self.makeErrorToast(
                                title: "Failed to ban user",
                                subTitle: "HTTP \(httpResponse.statusCode): \(statusMessage)"
                            )
                        }
                    }
                }
            }.resume()
        }
    }

    func deleteKickMessage(messageId: String, chatroomId: Int) {
        guard isKickLoggedIn() else {
            makeErrorToast(title: "Not logged in to Kick")
            return
        }

        let url = URL(string: "https://kick.com/api/v2/chatrooms/\(chatroomId)/messages/\(messageId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(stream.kickAccessToken)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.makeErrorToast(title: "Failed to delete message", subTitle: error.localizedDescription)
                    return
                }

                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 || httpResponse.statusCode == 204 {
                        self.makeToast(title: "Message deleted")
                    } else {
                        let statusMessage = HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
                        self.makeErrorToast(
                            title: "Failed to delete message",
                            subTitle: "HTTP \(httpResponse.statusCode): \(statusMessage)"
                        )
                    }
                }
            }
        }.resume()
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
