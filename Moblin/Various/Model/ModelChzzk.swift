import Foundation

private nonisolated(unsafe) let chzzkEmoteRegex = /\{:([^:{}]+):\}/

func makeChzzkChatSegments(message: String, emojis: [String: String]?) -> [ChatPostSegment] {
    guard let emojis, !emojis.isEmpty else {
        return makeChatPostTextSegments(text: message)
    }
    var segments: [ChatPostSegment] = []
    var id = 0
    var start = message.startIndex
    for match in message.matches(of: chzzkEmoteRegex) {
        let name = String(match.output.1)
        guard let value = emojis[name], let url = URL(string: value), url.scheme == "https" else {
            continue
        }
        segments += makeChatPostTextSegments(text: String(message[start ..< match.range.lowerBound]), id: &id)
        segments.append(ChatPostSegment(id: id, url: ChatPostEmote(moving: url, still: url, name: name)))
        id += 1
        start = match.range.upperBound
    }
    segments += makeChatPostTextSegments(text: String(message[start...]), id: &id)
    return segments
}

struct ChzzkViewerHistory {
    private var lastSeen: (status: PlatformStatus, time: ContinuousClock.Instant)?

    mutating func update(_ status: PlatformStatus?, at now: ContinuousClock.Instant) -> PlatformStatus {
        if let status {
            lastSeen = (status, now)
        }
        if let lastSeen, lastSeen.time.duration(to: now) < .seconds(120) {
            return lastSeen.status
        }
        return .unknown
    }
}

@MainActor
func performChzzkWrite(accessToken: (Bool) async throws -> String,
                       write: (String) async throws -> Void) async throws
{
    let token = try await accessToken(false)
    do {
        try await write(token)
    } catch ChzzkApiError.status(401) {
        let refreshed = try await accessToken(true)
        try await write(refreshed)
    }
}

func chzzkWriteErrorDetail(_ error: Error, action: ChzzkModerationAction?) -> String {
    switch error {
    case ChzzkChatSendError.messageTooLong:
        return String(localized: "CHZZK chat messages are limited to 100 characters.")
    case ChzzkApiError.status(400) where action == .hideMessage:
        return String(localized: "Log in with the streaming account to hide CHZZK messages.")
    case ChzzkApiError.status(401):
        return String(localized: "Log in to CHZZK again.")
    case ChzzkApiError.status(403):
        if action == nil || action == .hideMessage {
            return String(localized: "Check the CHZZK chat write permission and log in again.")
        }
        return String(localized: "Check the CHZZK restriction write permission and log in again.")
    case ChzzkApiError.status(404) where action != nil:
        return String(localized: "CHZZK could not find the selected message or user.")
    case ChzzkApiError.status(429):
        return String(localized: "Too many CHZZK requests. Try again later.")
    case is URLError:
        return String(localized: "Could not connect to CHZZK. Check your network and try again.")
    default:
        return action == nil ? String(localized: "Could not send a message to CHZZK.") :
            String(localized: "CHZZK could not complete this moderation action.")
    }
}

extension Model {
    func chzzkChannelUpdated() {
        reloadChzzkChat()
        reloadViewers()
        resetChat()
    }

    func isChzzkViewersConfigured() -> Bool {
        !stream.chzzkChannelId.isEmpty
    }

    func reloadChzzkViewers() {
        chzzkViewersTask?.cancel()
        chzzkViewersTask = nil
        chzzkPlatformStatus = .unknown
        let channelId = stream.chzzkChannelId
        guard !channelId.isEmpty else {
            return
        }
        chzzkViewersTask = Task { [weak self] in
            var history = ChzzkViewerHistory()
            while !Task.isCancelled {
                let status = try? await ChzzkApi.liveStatus(channelId: channelId)
                try Task.checkCancellation()
                self?.chzzkPlatformStatus = history.update(status, at: .now)
                try await sleep(seconds: 30)
            }
        }
    }

    func isChzzkEventsConfigured() -> Bool {
        chzzkLoggedIn
    }

    func isChzzkChatConfigured() -> Bool {
        database.chat.enabled && isChzzkEventsConfigured()
    }

    func sendChzzkChatMessage(message: String, isBotReply: Bool = false, showError: Bool = false) {
        let text: String
        do {
            text = try prepareChzzkChatMessage(message, isBotReply: isBotReply)
        } catch ChzzkChatSendError.emptyMessage {
            return
        } catch {
            if showError {
                makeErrorToast(title: String(localized: "Message not sent"),
                               subTitle: chzzkWriteErrorDetail(error, action: nil))
            }
            return
        }
        performChzzkChatAction(action: nil, showError: showError) { api, token in
            try await api.sendChatMessage(message: text, accessToken: token)
        }
    }

    func moderateChzzkChat(post: ChatPost, action: ChzzkModerationAction) {
        guard let target = post.chzzkTarget, target.supports(action),
              target.channelId == stream.chzzkChannelId, chzzkLoggedIn
        else {
            makeErrorToast(title: String(localized: "Could not manage this CHZZK message."))
            return
        }
        performChzzkChatAction(action: action, showError: true) { api, token in
            try await api.moderate(action, target: target, accessToken: token)
        } onSuccess: {
            if action == .hideMessage, let messageId = target.messageId {
                self.deleteChatMessage(messageId: messageId)
            }
            self.makeToast(title: String(localized: "CHZZK moderation updated."))
        }
    }

    private func performChzzkChatAction(action: ChzzkModerationAction?, showError: Bool,
                                        write: @escaping (ChzzkApi, String) async throws -> Void,
                                        onSuccess: @escaping () -> Void = {})
    {
        guard chzzkLoggedIn, let api = chzzkApi else {
            return
        }
        let streamId = stream.id
        let channelId = stream.chzzkChannelId
        Task {
            let isCurrentChannel = {
                self.stream.id == streamId && self.stream.chzzkChannelId == channelId && self.chzzkLoggedIn
            }
            do {
                try await performChzzkWrite { forceRefresh in
                    guard isCurrentChannel() else {
                        throw CancellationError()
                    }
                    return try await self.chzzkAccessToken(forceRefresh: forceRefresh)
                } write: { token in
                    guard isCurrentChannel() else {
                        throw CancellationError()
                    }
                    try await write(api, token)
                }
                if isCurrentChannel() {
                    onSuccess()
                }
            } catch {
                guard isCurrentChannel() else {
                    return
                }
                logger.debug("chzzk: Chat action failed")
                if showError {
                    let title = action == nil ? String(localized: "Message not sent") :
                        String(localized: "Could not manage this CHZZK message.")
                    makeErrorToast(title: title, subTitle: chzzkWriteErrorDetail(error, action: action))
                }
            }
        }
    }

    func reloadChzzkChat() {
        chzzkChat?.stop()
        chzzkChat = nil
        if isChzzkEventsConfigured(), !chzzkReadPermissionsDenied, let api = chzzkApi {
            let chat = ChzzkChat(api: api, accessToken: { [weak self] forceRefresh in
                guard let self else {
                    throw CancellationError()
                }
                return try await chzzkAccessToken(forceRefresh: forceRefresh)
            }, onChat: { [weak self] event in
                self?.appendChzzkChat(event)
            }, onDonation: { [weak self] event in
                self?.appendChzzkDonation(event)
            }, onPermissionsDenied: { [weak self] in
                self?.chzzkReadPermissionsDenied = true
                self?
                    .makeErrorToast(
                        title: String(
                            localized: "Check the CHZZK chat and donation read permissions and log in again."
                        )
                    )
            })
            chzzkChat = chat
            chat.start()
        }
        updateChatMoreThanOneChatConfigured()
    }

    private func appendChzzkChat(_ event: ChzzkChatMessage) {
        guard database.chat.enabled, event.channelId == stream.chzzkChannelId else {
            return
        }
        appendChatMessage(
            platform: .chzzk,
            messageId: event.moderationTarget.messageId,
            displayName: event.profile.nickname,
            user: event.profile.nickname,
            userId: event.senderChannelId,
            userColor: nil,
            userBadges: [],
            segments: makeChzzkChatSegments(message: event.content, emojis: event.emojis),
            timestamp: statusOther.digitalClock,
            timestampTime: .now,
            isAction: false,
            isSubscriber: false,
            isModerator: event.userRoleCode == "streaming_channel_manager"
                || event.userRoleCode == "streaming_chat_manager",
            isOwner: event.senderChannelId == event.channelId,
            bits: nil,
            highlight: nil,
            live: true,
            chzzkTarget: event.moderationTarget
        )
    }

    private func appendChzzkDonation(_ event: ChzzkDonation) {
        guard event.channelId == stream.chzzkChannelId else {
            return
        }
        let nickname = event.donatorNickname.flatMap { $0.isEmpty ? nil : $0 }
            ?? String(localized: "Anonymous")
        let title = String(localized: "Donated ₩\(event.payAmount)")
        makeToast(title: "\(nickname) · \(title)", subTitle: event.donationText)
        appendChatMessage(
            platform: .chzzk,
            messageId: nil,
            displayName: nickname,
            user: nickname,
            userId: event.donatorChannelId,
            userColor: nil,
            userBadges: [],
            segments: makeChatPostTextSegments(text: event.donationText ?? ""),
            timestamp: statusOther.digitalClock,
            timestampTime: .now,
            isAction: false,
            isSubscriber: false,
            isModerator: false,
            isOwner: false,
            bits: nil,
            highlight: ChatHighlight(kind: .other,
                                     barColor: .mint,
                                     image: "gift.fill",
                                     titleSegments: makeChatPostTextSegments(text: title)),
            live: true,
            chzzkTarget: event.moderationTarget
        )
    }
}
