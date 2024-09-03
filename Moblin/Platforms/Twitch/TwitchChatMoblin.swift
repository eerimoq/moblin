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

final class TwitchChatMoblin {
    private var model: Model
    private var webSocket: WebSocketClient
    private var emotes: Emotes
    private var channelName: String

    init(model: Model) {
        self.model = model
        channelName = ""
        emotes = Emotes()
        webSocket = .init(url: URL(string: "wss://irc-ws.chat.twitch.tv")!)
    }

    func start(channelName: String, channelId: String, settings: SettingsStreamChat) {
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
        webSocket.stop()
    }

    private func handleMessage(message: String) throws {
        guard let message = try ChatMessage(Message(string: message)) else {
            return
        }
        let emotes = getEmotes(from: message)
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
            emotesManager: self.emotes
        )
        model.appendChatMessage(
            platform: .twitch,
            user: message.sender,
            userColor: message.senderColor,
            segments: segments,
            timestamp: model.digitalClock,
            timestampTime: .now,
            isAction: isAction,
            isSubscriber: message.subscriber,
            isModerator: message.moderator,
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
                kind: .other,
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
                                emotesManager: Emotes) -> [ChatPostSegment]
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
