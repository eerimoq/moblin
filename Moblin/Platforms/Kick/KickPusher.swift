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
    private var webSocket: WebSocketClient
    private var emotes: Emotes
    private let settings: SettingsStreamChat
    private var gotInfo = false

    init(model: Model, channelId: String, channelName: String, settings: SettingsStreamChat) {
        self.model = model
        self.channelId = channelId
        self.channelName = channelName
        self.settings = settings.clone()
        emotes = Emotes()
        webSocket = .init(url: url)
    }

    func start() {
        logger.debug("kick: Start")
        stopInternal()
        if channelName.isEmpty {
            connect()
        } else {
            getInfoAndConnect()
        }
    }

    private func getInfoAndConnect() {
        logger.debug("kick: Get info and connect")
        getKickChannelInfo(channelName: channelName) { [weak self] channelInfo in
            guard let self else {
                return
            }
            DispatchQueue.main.async {
                guard !self.gotInfo else {
                    return
                }
                guard let channelInfo else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        self.getInfoAndConnect()
                    }
                    return
                }
                self.gotInfo = true
                self.channelId = String(channelInfo.chatroom.id)
                self.connect()
            }
        }
    }

    private func connect() {
        emotes.stop()
        emotes.start(
            platform: .kick,
            channelId: channelId,
            onError: handleError,
            onOk: handleOk,
            settings: settings
        )
        webSocket = .init(url: url)
        webSocket.delegate = self
        webSocket.start()
    }

    func stop() {
        logger.debug("kick: Stop")
        stopInternal()
    }

    func stopInternal() {
        emotes.stop()
        webSocket.stop()
        gotInfo = false
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

    private func handleMessage(message: String) {
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
            timestampTime: .now,
            isAction: false,
            isAnnouncement: false,
            isFirstMessage: false,
            isSubscriber: message.isSubscriber()
        )
    }

    private func sendMessage(message: String) {
        logger.debug("kick: pusher: \(channelId): Sending \(message)")
        webSocket.send(string: message)
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

extension KickPusher: WebSocketClientDelegate {
    func webSocketClientConnected() {
        logger.debug("kick: Connected")
        sendMessage(
            message: """
            {\"event\":\"pusher:subscribe\",
             \"data\":{\"auth\":\"\",\"channel\":\"chatrooms.\(channelId).v2\"}}
            """
        )
    }

    func webSocketClientDisconnected() {
        logger.debug("kick: Disconnected")
    }

    func webSocketClientReceiveMessage(string: String) {
        handleMessage(message: string)
    }
}
