import Network
import SwiftUI
import TwitchChat

private func getEmotes(from message: ChatMessage) -> [ChatMessageEmote] {
    var emotes: [ChatMessageEmote] = []
    for emote in message.emotes {
        do {
            try emotes.append(ChatMessageEmote(url: emote.imageURL, range: emote.range))
        } catch {
            logger.warning("twitch: chat: Failed to get emote URL")
        }
    }
    return emotes
}

private class Badges {
    private var channelId: String = ""
    private var accessToken: String = ""
    private var badges: [String: TwitchApiChatBadgesVersion] = [:]
    private var tryFetchAgainTimer: DispatchSourceTimer?

    func start(channelId: String, accessToken: String) {
        self.channelId = channelId
        self.accessToken = accessToken
        guard !accessToken.isEmpty else {
            return
        }
        tryFetch()
    }

    func stop() {
        stopTryFetchAgainTimer()
    }

    func getUrl(badgeId: String) -> String? {
        return badges[badgeId]?.image_url_2x
    }

    func tryFetch() {
        startTryFetchAgainTimer()
        TwitchApi(accessToken: accessToken).getGlobalChatBadges { data in
            guard let data else {
                return
            }
            DispatchQueue.main.async {
                self.addBadges(badges: data)
                TwitchApi(accessToken: self.accessToken)
                    .getChannelChatBadges(broadcasterId: self.channelId) { data in
                        guard let data else {
                            return
                        }
                        DispatchQueue.main.async {
                            self.addBadges(badges: data)
                            self.stopTryFetchAgainTimer()
                        }
                    }
            }
        }
    }

    private func startTryFetchAgainTimer() {
        tryFetchAgainTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        tryFetchAgainTimer!.schedule(deadline: .now() + 30)
        tryFetchAgainTimer!.setEventHandler { [weak self] in
            self?.tryFetch()
        }
        tryFetchAgainTimer!.activate()
    }

    private func stopTryFetchAgainTimer() {
        tryFetchAgainTimer?.cancel()
        tryFetchAgainTimer = nil
    }

    private func addBadges(badges: [TwitchApiChatBadgesData]) {
        for badge in badges {
            for version in badge.versions {
                self.badges["\(badge.set_id)/\(version.id)"] = version
            }
        }
    }
}

private class Cheermotes {
    private var channelId: String = ""
    private var accessToken: String = ""
    var emotes: [String: [TwitchApiGetCheermotesDataTier]] = [:]
    private var tryFetchAgainTimer: DispatchSourceTimer?

    func start(channelId: String, accessToken: String) {
        self.channelId = channelId
        self.accessToken = accessToken
        guard !accessToken.isEmpty else {
            return
        }
        tryFetch()
    }

    func stop() {
        stopTryFetchAgainTimer()
    }

    func tryFetch() {
        startTryFetchAgainTimer()
        TwitchApi(accessToken: accessToken).getCheermotes(broadcasterId: channelId) { datas in
            guard let datas else {
                return
            }
            DispatchQueue.main.async {
                self.addEmotes(datas: datas)
                self.stopTryFetchAgainTimer()
            }
        }
    }

    private func startTryFetchAgainTimer() {
        tryFetchAgainTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        tryFetchAgainTimer!.schedule(deadline: .now() + 30)
        tryFetchAgainTimer!.setEventHandler { [weak self] in
            self?.tryFetch()
        }
        tryFetchAgainTimer!.activate()
    }

    private func stopTryFetchAgainTimer() {
        tryFetchAgainTimer?.cancel()
        tryFetchAgainTimer = nil
    }

    private func addEmotes(datas: [TwitchApiGetCheermotesData]) {
        for data in datas {
            emotes[data.prefix.lowercased()] = data.tiers
        }
    }
}

final class TwitchChatMoblin {
    private var model: Model
    private var webSocket: WebSocketClient
    private var emotes: Emotes
    private var badges: Badges
    private var cheermotes: Cheermotes
    private var channelName: String

    init(model: Model) {
        self.model = model
        channelName = ""
        emotes = Emotes()
        badges = Badges()
        cheermotes = Cheermotes()
        webSocket = .init(url: URL(string: "wss://irc-ws.chat.twitch.tv")!)
    }

    func start(channelName: String, channelId: String, settings: SettingsStreamChat, accessToken: String) {
        self.channelName = channelName
        logger.debug("twitch: chat: Start")
        stopInternal()
        emotes.start(
            platform: .twitch,
            channelId: channelId,
            onError: handleError,
            onOk: handleOk,
            settings: settings
        )
        badges.start(channelId: channelId, accessToken: accessToken)
        cheermotes.start(channelId: channelId, accessToken: accessToken)
        webSocket = .init(url: URL(string: "wss://irc-ws.chat.twitch.tv")!)
        webSocket.delegate = self
        webSocket.start()
    }

    func stop() {
        logger.debug("twitch: chat: Stop")
        stopInternal()
    }

    func stopInternal() {
        emotes.stop()
        badges.stop()
        cheermotes.stop()
        webSocket.stop()
    }

    private func handleMessage(message: String) throws {
        guard let message = try ChatMessage(Message(string: message)) else {
            return
        }
        let emotes = getEmotes(from: message)
        var badgeUrls: [URL] = []
        for badge in message.badges {
            if let badgeUrl = badges.getUrl(badgeId: badge), let badgeUrl = URL(string: badgeUrl) {
                badgeUrls.append(badgeUrl)
            }
        }
        let text: String
        let isAction = message.isAction()
        if isAction {
            text = String(message.text.dropFirst(7))
        } else {
            text = message.text
        }
        let segments = createSegments(
            text: text,
            emotes: emotes,
            emotesManager: self.emotes,
            bits: message.bits
        )
        model.appendChatMessage(
            platform: .twitch,
            user: message.sender,
            userId: message.userId,
            userColor: RgbColor.fromHex(string: message.senderColor ?? ""),
            userBadges: badgeUrls,
            segments: segments,
            timestamp: model.digitalClock,
            timestampTime: .now,
            isAction: isAction,
            isSubscriber: message.subscriber,
            isModerator: message.moderator,
            bits: message.bits,
            highlight: createHighlight(message: message)
        )
    }

    private func createHighlight(message: ChatMessage) -> ChatHighlight? {
        if message.announcement {
            return .init(
                kind: .other,
                color: .green,
                image: "horn.blast",
                title: String(localized: "Announcement")
            )
        } else if message.firstMessage {
            return .init(
                kind: .firstMessage,
                color: .yellow,
                image: "bubble.left",
                title: String(localized: "First time chatter")
            )
        } else {
            return nil
        }
    }

    func isConnected() -> Bool {
        return webSocket.isConnected()
    }

    func hasEmotes() -> Bool {
        return emotes.isReady()
    }

    private func handleError(title: String, subTitle: String) {
        DispatchQueue.main.async {
            self.model.makeErrorToast(title: title, subTitle: subTitle)
        }
    }

    private func handleOk(title: String) {
        DispatchQueue.main.async {
            self.model.makeToast(title: title)
        }
    }

    private func createTwitchSegments(text: String,
                                      emotes: [ChatMessageEmote],
                                      id: inout Int) -> [ChatPostSegment]
    {
        var segments: [ChatPostSegment] = []
        let unicodeText = text.unicodeScalars
        var startIndex = unicodeText.startIndex
        for emote in emotes.sorted(by: { lhs, rhs in
            lhs.range.lowerBound < rhs.range.lowerBound
        }) {
            if !(emote.range.lowerBound < unicodeText.count) {
                logger
                    .warning(
                        """
                        twitch: chat: Emote lower bound \(emote.range.lowerBound) after \
                        message end \(unicodeText.count) '\(unicodeText)'
                        """
                    )
                break
            }
            if !(emote.range.upperBound < unicodeText.count) {
                logger
                    .warning(
                        """
                        twitch: chat: Emote upper bound \(emote.range.upperBound) after \
                        message end \(unicodeText.count) '\(unicodeText)'
                        """
                    )
                break
            }
            var text: String?
            if emote.range.lowerBound > 0 {
                let endIndex = unicodeText.index(
                    unicodeText.startIndex,
                    offsetBy: emote.range.lowerBound - 1
                )
                if startIndex < endIndex {
                    text = String(unicodeText[startIndex ... endIndex])
                }
            }
            if let text {
                segments += makeChatPostTextSegments(text: text, id: &id)
            }
            segments.append(ChatPostSegment(id: id, url: emote.url))
            id += 1
            segments.append(ChatPostSegment(id: id, text: ""))
            id += 1
            startIndex = unicodeText.index(
                unicodeText.startIndex,
                offsetBy: emote.range.upperBound + 1
            )
        }
        if startIndex < unicodeText.endIndex {
            for word in String(unicodeText[startIndex...]).split(separator: " ") {
                segments.append(ChatPostSegment(id: id, text: "\(word) "))
                id += 1
            }
        }
        return segments
    }

    private func createSegments(text: String,
                                emotes: [ChatMessageEmote],
                                emotesManager: Emotes,
                                bits: String?) -> [ChatPostSegment]
    {
        var segments: [ChatPostSegment] = []
        var id = 0
        for var segment in createTwitchSegments(text: text, emotes: emotes, id: &id) {
            if let text = segment.text {
                segments += emotesManager.createSegments(text: text, id: &id)
                segment.text = nil
            }
            if segment.text != nil || segment.url != nil {
                segments.append(segment)
            }
        }
        if bits != nil {
            for index in 0 ..< segments.count {
                guard let text = segments[index].text else {
                    continue
                }
                for (prefix, tiers) in cheermotes.emotes {
                    guard let regex = try? Regex("\(prefix)(\\d+)\\s", as: (Substring, Substring).self) else {
                        continue
                    }
                    guard let match = try? regex.wholeMatch(in: text.lowercased()) else {
                        continue
                    }
                    guard let bits = Int(match.output.1) else {
                        continue
                    }
                    guard let tier = tiers.reversed().first(where: { bits >= $0.min_bits }) else {
                        continue
                    }
                    if let url = URL(string: tier.images.dark.static_.two) {
                        segments[index] = .init(id: segments[index].id, text: nil, url: url)
                    }
                }
            }
        }
        return segments
    }
}

extension ChatMessage {
    func isAction() -> Bool {
        return text.starts(with: "\u{01}ACTION")
    }
}

extension TwitchChatMoblin: WebSocketClientDelegate {
    func webSocketClientConnected() {
        logger.debug("twitch: chat: Connected")
        webSocket.send(string: "CAP REQ :twitch.tv/membership")
        webSocket.send(string: "CAP REQ :twitch.tv/tags")
        webSocket.send(string: "CAP REQ :twitch.tv/commands")
        webSocket.send(string: "PASS oauth:SCHMOOPIIE")
        webSocket.send(string: "NICK justinfan67420")
        webSocket.send(string: "JOIN #\(channelName)")
    }

    func webSocketClientDisconnected() {
        logger.debug("twitch: chat: Disconnected")
    }

    func webSocketClientReceiveMessage(string: String) {
        for line in string.split(whereSeparator: { $0.isNewline }) {
            try? handleMessage(message: String(line))
        }
    }
}
