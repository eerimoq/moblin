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
    private var twitchChat: TwitchChat!
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
                logger.info("twitch: chat: \(channelName): Connecting")
                while true {
                    twitchChat = TwitchChat(
                        token: "SCHMOOPIIE",
                        nick: "justinfan67420",
                        name: channelName
                    )
                    do {
                        logger.info("twitch: chat: \(channelName): Connected")
                        connected = true
                        for try await message in self.twitchChat.messages {
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
                            await MainActor.run {
                                self.model.appendChatMessage(
                                    user: message.sender,
                                    userColor: message.senderColor,
                                    segments: segments,
                                    timestamp: model.digitalClock,
                                    timestampTime: .now,
                                    isAction: isAction,
                                    isAnnouncement: message.announcement,
                                    isFirstMessage: message.firstMessage,
                                    isSubscriber: message.subscriber
                                )
                            }
                        }
                    } catch {
                        logger.warning("twitch: chat: \(channelName): Got error \(error)")
                    }
                    logger.info("twitch: chat: \(channelName): Disconnected")
                    if Task.isCancelled {
                        return
                    }
                    connected = false
                    try await sleep(seconds: 5)
                    logger.info("twitch: chat: \(channelName): Reconnecting")
                }
            } catch {
                logger.info("Twitch chat ended with error \(error)")
            }
        }
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

extension ChatMessage {
    func isAction() -> Bool {
        return text.starts(with: "\u{01}ACTION")
    }
}
