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

extension Model {
    func chzzkChannelUpdated() {
        reloadChzzkChat()
        reloadViewers()
        resetChat()
    }

    func isChzzkViewersConfigured() -> Bool {
        !stream.chzzkChannelId.isEmpty && !chzzkClientId.isEmpty && !chzzkClientSecret.isEmpty
    }

    func reloadChzzkViewers() {
        chzzkViewersTask?.cancel()
        chzzkViewersTask = nil
        chzzkPlatformStatus = .unknown
        let channelId = stream.chzzkChannelId
        guard !channelId.isEmpty, let api = chzzkApi else {
            return
        }
        chzzkViewersTask = Task { [weak self] in
            var lastSeen: (count: Int, time: ContinuousClock.Instant)?
            while !Task.isCancelled {
                let count = try? await api.viewers(channelId: channelId)
                try Task.checkCancellation()
                let now = ContinuousClock.now
                if let count {
                    lastSeen = (count, now)
                }
                if let lastSeen, lastSeen.time.duration(to: now) < .seconds(120) {
                    self?.chzzkPlatformStatus = .live(viewerCount: lastSeen.count)
                } else {
                    self?.chzzkPlatformStatus = .unknown
                }
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
        guard chzzkLoggedIn, let api = chzzkApi else {
            return
        }
        let streamId = stream.id
        let channelId = stream.chzzkChannelId
        Task {
            let isCurrentChannel = {
                self.stream.id == streamId && self.stream.chzzkChannelId == channelId && self.chzzkLoggedIn
            }
            guard isCurrentChannel() else {
                return
            }
            do {
                let text = try prepareChzzkChatMessage(message, isBotReply: isBotReply)
                let token = try await chzzkAccessToken()
                guard isCurrentChannel() else {
                    return
                }
                do {
                    try await api.sendChatMessage(message: text, accessToken: token)
                } catch ChzzkApiError.status(401) {
                    guard isCurrentChannel() else {
                        return
                    }
                    let token = try await chzzkAccessToken(forceRefresh: true)
                    guard isCurrentChannel() else {
                        return
                    }
                    try await api.sendChatMessage(message: text, accessToken: token)
                }
            } catch ChzzkChatSendError.emptyMessage {
                return
            } catch {
                guard isCurrentChannel() else {
                    return
                }
                logger.debug("chzzk: Could not send chat message")
                if showError {
                    let detail = switch error {
                    case ChzzkChatSendError.messageTooLong:
                        String(localized: "CHZZK chat messages are limited to 100 characters.")
                    case ChzzkApiError.status(403):
                        String(localized: "Check the CHZZK chat write permission and log in again.")
                    default:
                        String(localized: "Could not send a message to CHZZK.")
                    }
                    makeErrorToast(title: String(localized: "Message not sent"), subTitle: detail)
                }
            }
        }
    }

    func reloadChzzkChat() {
        chzzkChat?.stop()
        chzzkChat = nil
        if isChzzkEventsConfigured(), let api = chzzkApi {
            let chat = ChzzkChat(api: api, accessToken: { [weak self] forceRefresh in
                guard let self else {
                    throw CancellationError()
                }
                return try await chzzkAccessToken(forceRefresh: forceRefresh)
            }, onChat: { [weak self] event in
                self?.appendChzzkChat(event)
            }, onDonation: { [weak self] event in
                self?.appendChzzkDonation(event)
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
            messageId: nil,
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
            live: true
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
            live: true
        )
    }
}
