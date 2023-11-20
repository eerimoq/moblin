import Foundation

private struct Sender: Decodable {
    var username: String
}

private struct ChatMessage: Decodable {
    var content: String
    var sender: Sender
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
    private var webSocket: URLSessionWebSocketTask
    private var channelId: String
    private var reconnectTimer: Timer?
    private var reconnectTime = firstReconnectTime
    private var running = true
    private var emotes: Emotes

    init(model: Model, channelId: String) {
        self.model = model
        self.channelId = channelId
        emotes = Emotes()
        webSocket = URLSession(configuration: .default).webSocketTask(with: url)
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

    func start() {
        reconnectTime = firstReconnectTime
        setupWebsocket()
        emotes.start(
            platform: .kick,
            channelId: channelId,
            onError: handleError,
            onOk: handleOk
        )
    }

    func stop() {
        emotes.stop()
        webSocket.cancel()
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        running = false
    }

    func isConnected() -> Bool {
        return webSocket.state == .running
    }

    func hasEmotes() -> Bool {
        return emotes.isReady()
    }

    private func setupWebsocket() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        let session = URLSession(configuration: .default,
                                 delegate: self,
                                 delegateQueue: OperationQueue.main)
        webSocket = session.webSocketTask(with: url)
        webSocket.resume()
        readMessage()
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
            userColor: nil,
            segments: segments,
            timestamp: model.digitalClock,
            timestampDate: Date()
        )
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

    private func reconnect() {
        webSocket.cancel()
        reconnectTimer?.invalidate()
        reconnectTimer = Timer
            .scheduledTimer(withTimeInterval: reconnectTime, repeats: false) { _ in
                logger.warning("kick: pusher: \(self.channelId): Reconnecting")
                self.setupWebsocket()
                self.reconnectTime = nextReconnectTime(self.reconnectTime)
            }
    }

    private func readMessage() {
        webSocket.receive { result in
            switch result {
            case .failure:
                return
            case let .success(message):
                switch message {
                case let .string(text):
                    self.handleStringMessage(message: text)
                case let .data(data):
                    logger
                        .error("""
                        kick: pusher: \(self.channelId): Received binary \
                        message: \(data)
                        """)
                @unknown default:
                    logger
                        .warning(
                            "kick: pusher: \(self.channelId): Unknown message type"
                        )
                }
                self.readMessage()
            }
        }
    }

    private func sendMessage(message: String) {
        logger.debug("kick: pusher: \(channelId): Sending \(message)")
        let message = URLSessionWebSocketTask.Message.string(message)
        webSocket.send(message) { error in
            if let error {
                logger
                    .error("""
                    kick: pusher: \(self.channelId): Failed to send \
                    message to server with error \(error)
                    """)
                self.reconnect()
            }
        }
    }
}

extension KickPusher: URLSessionWebSocketDelegate {
    func urlSession(
        _: URLSession,
        webSocketTask _: URLSessionWebSocketTask,
        didOpenWithProtocol _: String?
    ) {
        logger.debug("kick: pusher: \(channelId): Connected to \(url)")
        reconnectTime = firstReconnectTime
        sendMessage(
            message: """
            {\"event\":\"pusher:subscribe\",
             \"data\":{\"auth\":\"\",\"channel\":\"chatrooms.\(channelId).v2\"}}
            """
        )
    }

    func urlSession(
        _: URLSession,
        webSocketTask _: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        logger
            .warning(
                """
                kick: pusher: \(channelId): Disconnected from server with close \
                code \(closeCode) and reason \(String(describing: reason))
                """
            )
        reconnect()
    }

    func urlSession(
        _: URLSession,
        task _: URLSessionTask,
        didCompleteWithError _: Error?
    ) {
        if running {
            logger.info("kick: pusher: \(channelId): Completed")
            reconnect()
        } else {
            logger.info("kick: pusher: \(channelId): Completed by us")
        }
    }
}
