import SwiftUI
import TwitchChat

private var emotesCache: [String: UIImage] = [:]

private func getEmotes(from message: ChatMessage) async -> [ChatMessageEmote] {
    var emotes: [ChatMessageEmote] = []
    for emote in message.emotes {
        do {
            if let emoteImage = try emotesCache[emote.imageURL.path] {
                emotes.append(ChatMessageEmote(image: emoteImage, range: emote.range))
            } else {
                let data = try await httpGet(from: emote.imageURL)
                guard let emoteImage = UIImage(data: data) else {
                    throw "Not an image"
                }
                try emotesCache[emote.imageURL.path] = emoteImage
                emotes.append(ChatMessageEmote(image: emoteImage, range: emote.range))
            }
        } catch {
            logger.warning("twitch: chat: Failed to download emote")
        }
    }
    return emotes
}

final class TwitchChatMobs {
    private var twitchChat: TwitchChat!
    private var model: Model
    private var task: Task<Void, Error>?
    private var connected: Bool = false

    init(model: Model) {
        self.model = model
    }

    func isConnected() -> Bool {
        return connected
    }

    private func createTwitchSegments(message: ChatMessage,
                                      emotes: [ChatMessageEmote]) -> [ChatPostSegment]
    {
        var segments: [ChatPostSegment] = []
        var startIndex = message.text.startIndex
        for emote in emotes.sorted(by: { lhs, rhs in
            lhs.range.lowerBound < rhs.range.lowerBound
        }) {
            var text: String?
            if emote.range.lowerBound > 0 {
                let endIndex = message.text.index(
                    message.text.startIndex,
                    offsetBy: emote.range.lowerBound - 1
                )
                if startIndex < endIndex {
                    text = String(message.text[startIndex ... endIndex])
                }
            }
            segments.append(ChatPostSegment(
                text: text,
                image: emote.image
            ))
            startIndex = message.text.index(
                message.text.startIndex,
                offsetBy: min(emote.range.upperBound + 1, message.text.count)
            )
        }
        if startIndex < message.text.endIndex {
            let text = message.text[startIndex...]
            segments.append(ChatPostSegment(text: String(text)))
        }
        return segments
    }

    private func createSegments(message: ChatMessage,
                                emotes: [ChatMessageEmote],
                                emotesManager: Emotes) async -> [ChatPostSegment]
    {
        var segments: [ChatPostSegment] = []
        let twitchSegments = createTwitchSegments(message: message, emotes: emotes)
        for var segment in twitchSegments {
            if let text = segment.text {
                segments += await emotesManager.createSegments(text: text)
                segment.text = nil
            }
            segments.append(segment)
        }
        return segments
    }

    func start(channelName: String, channelId: String) {
        task = Task.init {
            var reconnectTime = firstReconnectTime
            logger.info("twitch: chat: \(channelName): Connecting")
            let emotesManager = await Emotes(channelId: channelId)
            while true {
                twitchChat = TwitchChat(
                    token: "SCHMOOPIIE",
                    nick: "justinfan67420",
                    name: channelName
                )
                do {
                    connected = true
                    for try await message in self.twitchChat.messages {
                        let emotes = await getEmotes(from: message)
                        reconnectTime = firstReconnectTime
                        let segments = await createSegments(
                            message: message,
                            emotes: emotes,
                            emotesManager: emotesManager
                        )
                        await MainActor.run {
                            self.model.appendChatMessage(
                                user: message.sender,
                                userColor: message.senderColor,
                                segments: segments
                            )
                        }
                    }
                } catch {
                    logger.warning("twitch: chat: \(channelName): Got error \(error)")
                }
                connected = false
                logger.info("twitch: chat: \(channelName): Disconnected")
                try await Task.sleep(nanoseconds: UInt64(reconnectTime * 1_000_000_000))
                reconnectTime = nextReconnectTime(reconnectTime)
                logger.info("twitch: chat: \(channelName): Reconnecting")
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}
