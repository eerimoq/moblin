import SwiftUI
import Twitch
import TwitchIRC

private func getEmotes(from message: PrivateMessage) -> [ChatMessageEmote] {
    let emotes: [TwitchIRC.Emote] = message.parseEmotes()
    return emotes.map {
        ChatMessageEmote(
            url: URL(string: "https://static-cdn.jtvnw.net/emoticons/v2/\($0.id)/default/dark/3.0")!,
            range: $0.startIndex ... $0.endIndex
        )
    }
}

final class TwitchChatMoblin {
    private var chatClient: ChatClient!
    private var model: Model
    private var task: Task<Void, Error>?
    private var connected: Bool = false
    private var emotes: Emotes

    init(model: Model) {
        self.model = model
        emotes = Emotes()
    }

    func start(channelName: String, channelId: String, settings: SettingsStreamChat!) {
        emotes.start(
            platform: .twitch,
            channelId: channelId,
            onError: handleError,
            onOk: handleOk,
            settings: settings
        )
        task = Task.init {
            do {
                var reconnectTime = firstReconnectTime
                logger.info("twitch: chat: \(channelName): Connecting")
                chatClient = ChatClient(.anonymous)
                while true {
                    do {
                        let stream = try await chatClient.connect()
                        logger.info("twitch: chat: \(channelName): Connected")
                        connected = true
                        try await chatClient.join(to: channelName)
                        logger.info("twitch: chat: \(channelName): joined channel")
                        for try await message in stream {
                            reconnectTime = firstReconnectTime
                            await processMessage(message)
                        }
                    } catch {
                        logger.warning("twitch: chat: \(channelName): Got error \(error)")
                    }
                    logger.info("twitch: chat: \(channelName): Disconnected")
                    if Task.isCancelled {
                        return
                    }
                    connected = false
                    try await Task
                        .sleep(nanoseconds: UInt64(reconnectTime * 1_000_000_000))
                    reconnectTime = nextReconnectTime(reconnectTime)
                    logger.info("twitch: chat: \(channelName): Reconnecting")
                }
            } catch {
                logger.info("Twitch chat ended with error \(error)")
            }
        }
    }

    func processMessage(_ message: IncomingMessage) async {
        switch message {
        case let .privateMessage(chatMessage):
            await processChatMessage(chatMessage)
        case let .userNotice(announcement):
            await processAnnouncement(announcement)
        default:
            break
        }
    }

    func processChatMessage(_ chatMessage: PrivateMessage) async {
        let emotes = getEmotes(from: chatMessage)
        let text: String = chatMessage.message
        let segments = createSegments(
            text: text,
            emotes: emotes,
            emotesManager: self.emotes
        )
        await MainActor.run {
            self.model.appendChatMessage(
                user: chatMessage.displayName,
                userColor: chatMessage.color,
                segments: segments,
                timestamp: model.digitalClock,
                timestampDate: Date(),
                isAction: chatMessage.message.starts(with: "\u{01}ACTION"),
                isAnnouncement: false,
                isFirstMessage: chatMessage.firstMessage
            )
        }
    }

    func processAnnouncement(_: UserNotice) async {
        // TODO:
    }

    func stop() {
        emotes.stop()
        task?.cancel()
        task = nil
        connected = false
    }

    func isConnected() -> Bool {
        return connected
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
                                      emotes: [ChatMessageEmote]) -> [ChatPostSegment]
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
                segments += makeChatPostTextSegments(text: text)
            }
            segments.append(ChatPostSegment(url: emote.url))
            segments.append(ChatPostSegment(text: ""))
            startIndex = unicodeText.index(
                unicodeText.startIndex,
                offsetBy: emote.range.upperBound + 1
            )
        }
        if startIndex < unicodeText.endIndex {
            for word in String(unicodeText[startIndex...]).split(separator: " ") {
                segments.append(ChatPostSegment(text: "\(word) "))
            }
        }
        return segments
    }

    private func createSegments(text: String,
                                emotes: [ChatMessageEmote],
                                emotesManager: Emotes) -> [ChatPostSegment]
    {
        var segments: [ChatPostSegment] = []
        for var segment in createTwitchSegments(text: text, emotes: emotes) {
            if let text = segment.text {
                segments += emotesManager.createSegments(text: text)
                segment.text = nil
            }
            segments.append(segment)
        }
        return segments
    }
}
