import Foundation

private struct Badge: Decodable {
    var type: String
}

private struct Identity: Decodable {
    var color: String
    var badges: [Badge]
}

private struct Sender: Decodable {
    var username: String
    var identity: Identity
}

private struct ChatMessage: Decodable {
    var content: String
    var sender: Sender

    func isSubscriber() -> Bool {
        return sender.identity.badges.contains(where: { $0.type == "subscriber" })
    }
}

private func decodeEvent(message: String) throws -> (String, String) {
    if let jsonData = message.data(using: String.Encoding.utf8) {
        let data = try JSONSerialization.jsonObject(
            with: jsonData,
            options: JSONSerialization.ReadingOptions.mutableContainers
        )
        if let jsonResult: NSDictionary = data as? NSDictionary {
            if let type: String = jsonResult["event"] as? String {
                if let data: String = jsonResult["data"] as? String {
                    return (type, data)
                }
            }
        }
    }
    throw "Failed to get message event type"
}

private func decodeChatMessage(data: String) throws -> ChatMessage {
    return try JSONDecoder().decode(
        ChatMessage.self,
        from: data.data(using: String.Encoding.utf8)!
    )
}

private var url =
    URL(
        string: "wss://ws-us2.pusher.com/app/eb1d5f283081a78b932c?protocol=7&client=js&version=7.6.0&flash=false"
    )!

final class KickPusher: NSObject {
    private var model: Model
    private var channelName: String
    private var channelId: String
    private var task: Task<Void, Error>?
    private var connected: Bool = false
    private var webSocket: URLSessionWebSocketTask
    private var emotes: Emotes
    private let settings: SettingsStreamChat

    init(model: Model, channelId: String, channelName: String, settings: SettingsStreamChat) {
        self.model = model
        self.channelId = channelId
        self.channelName = channelName
        self.settings = settings.clone()
        emotes = Emotes()
        webSocket = URLSession(configuration: .default).webSocketTask(with: url)
    }

    func start() {
        stop()
        emotes.start(
            platform: .twitch,
            channelId: channelId,
            onError: handleError,
            onOk: handleOk,
            settings: settings
        )
        logger.debug("kick: start")
        task = Task.init {
            while true {
                do {
                    if !channelName.isEmpty {
                        let info = try await getKickChannelInfo(channelName: channelName)
                        channelId = String(info.chatroom.id)
                    }
                    try await setupConnection(chatroomId: channelId)
                    connected = true
                    try await receiveMessages()
                } catch {
                    logger.debug("kick: error: \(error)")
                }
                if Task.isCancelled {
                    logger.debug("kick: Cancelled")
                    connected = false
                    break
                }
                logger.debug("kick: Disconnected")
                connected = false
                try await sleep(seconds: 5)
                logger.debug("kick: Reconnecting")
            }
        }
    }

    func stop() {
        logger.debug("kick: stop")
        emotes.stop()
        task?.cancel()
        task = nil
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

    private func setupConnection(chatroomId _: String) async throws {
        webSocket = URLSession.shared.webSocketTask(with: url)
        webSocket.resume()
        try await sendMessage(
            message: """
            {\"event\":\"pusher:subscribe\",
             \"data\":{\"auth\":\"\",\"channel\":\"chatrooms.\(channelId).v2\"}}
            """
        )
    }

    private func receiveMessages() async throws {
        while true {
            let message = try await webSocket.receive()
            if Task.isCancelled {
                break
            }
            switch message {
            case let .string(text):
                handleStringMessage(message: text)
            case let .data(data):
                logger
                    .error("""
                    kick: pusher: \(channelId): Received binary \
                    message: \(data)
                    """)
            @unknown default:
                logger
                    .warning(
                        "kick: pusher: \(channelId): Unknown message type"
                    )
            }
        }
    }

    private func handleStringMessage(message: String) {
        do {
            let (type, data) = try decodeEvent(message: message)
            if type == "App\\Events\\ChatMessageEvent" {
                try handleChatMessageEvent(data: data)
            } else {
                logger.debug("kick: pusher: \(channelId): Unsupported type: \(type)")
            }
        } catch {
            logger
                .error("""
                kick: pusher: \(channelId): Failed to process \
                message \"\(message)\" with error \(error)
                """)
        }
    }

    private func handleChatMessageEvent(data: String) throws {
        let message = try decodeChatMessage(data: data)
        var segments: [ChatPostSegment] = []
        for var segment in createKickSegments(message: message.content) {
            if let text = segment.text {
                segments += emotes.createSegments(text: text)
                segment.text = nil
            }
            segments.append(segment)
        }
        model.appendChatMessage(
            user: message.sender.username,
            userColor: message.sender.identity.color,
            segments: segments,
            timestamp: model.digitalClock,
            timestampDate: Date(),
            isAction: false,
            isAnnouncement: false,
            isFirstMessage: false,
            isSubscriber: message.isSubscriber()
        )
    }

    private func sendMessage(message: String) async throws {
        logger.debug("kick: pusher: \(channelId): Sending \(message)")
        try await webSocket.send(URLSessionWebSocketTask.Message.string(message))
    }

    private func createKickSegments(message: String) -> [ChatPostSegment] {
        var segments: [ChatPostSegment] = []
        var startIndex = message.startIndex
        for match in message[startIndex...].matches(of: /\[emote:(\d+):[^\]]+\]/) {
            let emoteId = match.output.1
            let textBeforeEmote = message[startIndex ..< match.range.lowerBound]
            let url = URL(string: "https://files.kick.com/emotes/\(emoteId)/fullsize")
            segments += makeChatPostTextSegments(text: String(textBeforeEmote))
            segments.append(ChatPostSegment(url: url))
            startIndex = match.range.upperBound
        }
        if startIndex != message.endIndex {
            segments += makeChatPostTextSegments(text: String(message[startIndex...]))
        }
        return segments
    }
}
