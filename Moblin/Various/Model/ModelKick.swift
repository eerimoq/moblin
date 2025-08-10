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
        Task {
            do {
                try await performKickMessageSend(message: message)
            } catch {
                await MainActor.run {
                    handleKickSendError(error)
                }
            }
        }
    }

    private func performKickMessageSend(message: String) async throws {
        guard isKickLoggedIn() else {
            throw KickSendError.notLoggedIn
        }
        guard !stream.kickChannelName.isEmpty else {
            throw KickSendError.channelNotSet
        }
        let channelInfo = try await getKickChannelInfoAsync(channelName: stream.kickChannelName)
        try await sendKickMessageToAPI(chatroomId: channelInfo.chatroom.id, message: message)
    }

    private func sendKickMessageToAPI(chatroomId: Int, message: String) async throws {
        guard let url = URL(string: "https://kick.com/api/v2/messages/send/\(chatroomId)") else {
            throw KickSendError.invalidURL
        }
        let request = createKickMessageRequest(url: url, message: message)
        let (_, response) = try await URLSession.shared.data(for: request)
        try validateKickResponse(response)
    }

    private func createKickAPIRequest(url: URL, method: String = "POST") -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(stream.kickAccessToken)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func createKickMessageRequest(url: URL, message: String) -> URLRequest {
        var request = createKickAPIRequest(url: url)
        let body = ["content": message, "type": "message"]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func validateKickResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw KickSendError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            throw KickSendError.httpError(httpResponse.statusCode)
        }
    }

    func getKickChannelInfoAsync(channelName: String) async throws -> KickChannel {
        if let cached = kickChannelInfoCache, cached.isValid(for: channelName) {
            return cached.channelInfo
        }
        let channelInfo = try await withCheckedThrowingContinuation { continuation in
            getKickChannelInfo(channelName: channelName) { channelInfo in
                if let channelInfo = channelInfo {
                    continuation.resume(returning: channelInfo)
                } else {
                    continuation.resume(throwing: KickSendError.channelInfoFailed)
                }
            }
        }
        kickChannelInfoCache = CachedKickChannelInfo(
            channelInfo: channelInfo,
            timestamp: Date(),
            channelName: channelName
        )
        return channelInfo
    }

    private func handleKickSendError(_ error: Error) {
        let (title, subtitle) = getKickErrorMessages(for: error)
        makeErrorToast(title: title, subTitle: subtitle)
    }

    private func getKickErrorMessages(for error: Error) -> (String, String?) {
        if let kickError = error as? KickSendError {
            switch kickError {
            case .notLoggedIn:
                return ("Not logged in to Kick", nil)
            case .channelNotSet:
                return ("Channel name not set", nil)
            case .channelInfoFailed:
                return ("Failed to get channel info", nil)
            case .invalidURL:
                return ("Invalid API URL", nil)
            case .invalidResponse:
                return ("Invalid server response", nil)
            case let .httpError(code):
                let message = HTTPURLResponse.localizedString(forStatusCode: code)
                return ("Failed to send message", "HTTP \(code): \(message)")
            }
        } else {
            return ("Failed to send message", error.localizedDescription)
        }
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
        Task {
            do {
                let channelInfo = try await getKickChannelInfoAsync(channelName: stream.kickChannelName)
                try await performKickUserBan(user: user, duration: duration, reason: reason, channelInfo: channelInfo)
            } catch {
                await MainActor.run {
                    if let kickError = error as? KickSendError {
                        let (title, subtitle) = getKickErrorMessages(for: kickError)
                        makeErrorToast(title: title, subTitle: subtitle)
                    } else {
                        makeErrorToast(title: "Failed to ban user", subTitle: error.localizedDescription)
                    }
                }
            }
        }
    }

    private func performKickUserBan(
        user: String,
        duration: Int?,
        reason: String,
        channelInfo: KickChannel
    ) async throws {
        let slug = channelInfo.slug
        guard let url = URL(string: "https://kick.com/api/v2/channels/\(slug)/bans") else {
            throw KickSendError.invalidURL
        }
        var request = createKickAPIRequest(url: url)
        var body: [String: Any] = [
            "banned_username": user,
            "permanent": duration == nil,
        ]
        if !reason.isEmpty {
            body["reason"] = reason
        }
        if let duration = duration {
            body["duration"] = duration / 60
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw KickSendError.invalidResponse
        }
        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
            throw KickSendError.httpError(httpResponse.statusCode)
        }
        await MainActor.run {
            if let duration = duration {
                let minutes = duration / 60
                if minutes < 60 {
                    let timeText = minutes == 1 ? "1 minute" : "\(minutes) minutes"
                    makeToast(title: String(localized: "Successfully timed out \(user) for \(timeText)"))
                } else {
                    let hours = minutes / 60
                    let timeText = hours == 1 ? "1 hour" : "\(hours) hours"
                    makeToast(title: String(localized: "Successfully timed out \(user) for \(timeText)"))
                }
            } else {
                makeToast(title: String(localized: "Successfully banned \(user)"))
            }
        }
    }

    func deleteKickMessage(messageId: String, chatroomId: Int) {
        guard isKickLoggedIn() else {
            makeErrorToast(title: "Not logged in to Kick")
            return
        }
        let url = URL(string: "https://kick.com/api/v2/chatrooms/\(chatroomId)/messages/\(messageId)")!
        let request = createKickAPIRequest(url: url, method: "DELETE")
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
