import Foundation

struct MessageData: Decodable {
    var message: String
}

struct Message: Decodable {
    var data: MessageData
}

struct Response: Decodable {}

struct MessageViewCount: Decodable {
    var viewers: Int
}

func getMessageType(message: String) throws -> String {
    if let jsonData = message.data(using: String.Encoding.utf8) {
        let data = try JSONSerialization.jsonObject(
            with: jsonData,
            options: JSONSerialization.ReadingOptions.mutableContainers
        )
        if let jsonResult: NSDictionary = data as? NSDictionary {
            if let type: String = jsonResult["type"] as? String {
                return type
            }
        }
    }

    throw "Failed to get message type"
}

func decodeResponse(message: String) throws -> Response {
    return try JSONDecoder().decode(
        Response.self,
        from: message.data(using: String.Encoding.utf8)!
    )
}

func decodeMessage(message: String) throws -> Message {
    return try JSONDecoder().decode(
        Message.self,
        from: message.data(using: String.Encoding.utf8)!
    )
}

func decodeMessageViewCount(message: String) throws -> MessageViewCount {
    return try JSONDecoder().decode(
        MessageViewCount.self,
        from: message.data(using: String.Encoding.utf8)!
    )
}

var url = URL(string: "wss://pubsub-edge.twitch.tv/v1")!

final class TwitchPubSub: NSObject, URLSessionWebSocketDelegate {
    private var model: Model
    private var webSocket: URLSessionWebSocketTask
    private var channelId: String
    private var keepAliveTimer: Timer?
    private var reconnectTimer: Timer?
    private var reconnectTime = firstReconnectTime
    private var running = true

    init(model: Model, channelId: String) {
        self.model = model
        self.channelId = channelId
        webSocket = URLSession(configuration: .default).webSocketTask(with: url)
    }

    func start() {
        reconnectTime = firstReconnectTime
        setupWebsocket()
    }

    func stop() {
        webSocket.cancel()
        keepAliveTimer?.invalidate()
        reconnectTimer?.invalidate()
        running = false
    }

    func isConnected() -> Bool {
        return webSocket.state == .running
    }

    func setupWebsocket() {
        keepAliveTimer?.invalidate()
        reconnectTimer?.invalidate()
        let session = URLSession(configuration: .default,
                                 delegate: self,
                                 delegateQueue: OperationQueue.main)
        webSocket = session.webSocketTask(with: url)
        webSocket.resume()
        readMessage()
    }

    func handlePong() {
        keepAliveTimer?.invalidate()
        keepAliveTimer = Timer
            .scheduledTimer(withTimeInterval: 4 * 60 + 30, repeats: false) { _ in
                self.sendPing()
            }
    }

    func handleResponse(message: String) throws {
        _ = try decodeResponse(message: message)
    }

    func handleMessage(message: String) throws {
        let message = try decodeMessage(message: message)
        let type = try getMessageType(message: message.data.message)
        if type == "viewcount" {
            let message = try decodeMessageViewCount(message: message.data.message)
            model.numberOfViewers = String(message.viewers)
            model.numberOfViewersUpdateDate = Date()
        } else {
            logger
                .debug(
                    "twitch: pubsub: \(channelId): Unsupported message type \(type) (message: \(message))"
                )
        }
    }

    func handleStringMessage(message: String) {
        do {
            let type = try getMessageType(message: message)
            if type == "PONG" {
                handlePong()
            } else if type == "RESPONSE" {
                try handleResponse(message: message)
            } else if type == "MESSAGE" {
                try handleMessage(message: message)
            } else {
                logger.debug("twitch: pubsub: \(channelId): Unsupported type: \(type)")
            }
        } catch {
            logger
                .error(
                    "twitch: pubsub: \(channelId): Failed to process message \"\(message)\" with error \(error)"
                )
        }
    }

    func reconnect() {
        webSocket.cancel()
        reconnectTimer?.invalidate()
        reconnectTimer = Timer
            .scheduledTimer(withTimeInterval: reconnectTime, repeats: false) { _ in
                logger.warning("twitch: pubsub: \(self.channelId): Reconnecting")
                self.setupWebsocket()
                self.reconnectTime = nextReconnectTime(self.reconnectTime)
            }
    }

    func readMessage() {
        webSocket.receive { result in
            switch result {
            case .failure:
                // logger.warning("twitch: pubsub: \(self.channelId): Receive failed with error: \(error)")
                self.reconnect()
                return
            case let .success(message):
                switch message {
                case let .string(text):
                    logger
                        .debug(
                            "twitch: pubsub: \(self.channelId): Received string \(text)"
                        )
                    self.handleStringMessage(message: text)
                case let .data(data):
                    logger
                        .error(
                            "twitch: pubsub: \(self.channelId): Received binary message: \(data)"
                        )
                @unknown default:
                    logger
                        .warning(
                            "twitch: pubsub: \(self.channelId): Unknown message type"
                        )
                }
                self.readMessage()
            }
        }
    }

    func sendMessage(message: String) {
        logger.debug("twitch: pubsub: \(channelId): Sending \(message)")
        let message = URLSessionWebSocketTask.Message.string(message)
        webSocket.send(message) { error in
            if let error {
                logger
                    .error(
                        "twitch: pubsub: \(self.channelId): Failed to send message to server with error \(error)"
                    )
                self.reconnect()
            }
        }
    }

    func sendPing() {
        sendMessage(message: "{\"type\":\"PING\"}")
        keepAliveTimer?.invalidate()
        keepAliveTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { _ in
            logger
                .warning(
                    "twitch: pubsub: \(self.channelId): Timeout waiting for pong. Reconnecting"
                )
            self.webSocket.cancel()
            self.setupWebsocket()
        }
    }

    func urlSession(
        _: URLSession,
        webSocketTask _: URLSessionWebSocketTask,
        didOpenWithProtocol _: String?
    ) {
        logger.info("twitch: pubsub: \(channelId): Connected to \(url)")
        reconnectTime = firstReconnectTime
        sendPing()
        sendMessage(
            message: "{\"type\":\"LISTEN\",\"data\":{\"topics\":[\"video-playback-by-id.\(channelId)\"]}}"
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
                twitch: pubsub: \(channelId): Disconnected from server with close \
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
            logger.info("twitch: pubsub: \(channelId): Completed")
            reconnect()
        } else {
            logger.info("twitch: pubsub: \(channelId): Completed by us")
        }
    }
}
