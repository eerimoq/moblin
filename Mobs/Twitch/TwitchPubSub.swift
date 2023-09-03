import Foundation

struct MessageData: Decodable {
    var topic: String
    var message: String
}

struct Message: Decodable {
    var type: String
    var data: MessageData
}

struct Response: Decodable {
    var type: String
    var nonce: String
    var error: String
}

struct MessageViewCount: Decodable {
    var viewers: Int
}

func getMessageType(message: String) throws -> String {
    if let jsonData = message.data(using: String.Encoding.utf8) {
        let data = try JSONSerialization.jsonObject(with: jsonData, options: JSONSerialization.ReadingOptions.mutableContainers)
        if let jsonResult: NSDictionary = data as? NSDictionary {
            if let type: String = jsonResult["type"] as? String {
                return type
            }
        }
    }

    throw "Failed to get message type"
}

func decodeResponse(message: String) throws -> Response {
    return try JSONDecoder().decode(Response.self, from: message.data(using: String.Encoding.utf8)!)
}

func decodeMessage(message: String) throws -> Message {
    return try JSONDecoder().decode(Message.self, from: message.data(using: String.Encoding.utf8)!)
}

func decodeMessageViewCount(message: String) throws -> MessageViewCount {
    return try JSONDecoder().decode(MessageViewCount.self, from: message.data(using: String.Encoding.utf8)!)
}

var url = URL(string: "wss://pubsub-edge.twitch.tv/v1")!

final class TwitchPubSub: NSObject, URLSessionWebSocketDelegate {
    private var model: Model
    private var webSocket: URLSessionWebSocketTask
    private var channelId: String
    private var keepAliveTimer: Timer? = nil
    private var reconnectTimer: Timer? = nil
    private var reconnectTime = 2.0
    
    init(model: Model, channelId: String) {
        self.model = model
        self.channelId = channelId
        self.webSocket = URLSession(configuration: .default).webSocketTask(with: url)
    }

    func start() {
        reconnectTime = 2.0
        setupWebsocket()
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
        
    func stop() {
        webSocket.cancel()
        keepAliveTimer?.invalidate()
        reconnectTimer?.invalidate()
    }
    
    func handlePong() {
        keepAliveTimer?.invalidate()
        keepAliveTimer = Timer.scheduledTimer(withTimeInterval: 4 * 60 + 30, repeats: false) { _ in
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
            self.model.numberOfViewers = "\(message.viewers)"
        } else {
            logger.debug("pubsub: Unsupported message type \(type) (message: \(message))")
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
                logger.debug("pubsub: Unsupported type: \(type)")
            }
        } catch {
            logger.error("pubsub: Failed to process message \"\(message)\" with error \(error)")
        }
    }

    func readMessage()  {
        webSocket.receive { result in
            switch result {
            case .failure(let error):
                logger.error("pubsub: Receive failed with error: \(error)")
                self.reconnectTimer?.invalidate()
                self.reconnectTimer = Timer.scheduledTimer(withTimeInterval: self.reconnectTime, repeats: false) { _ in
                    logger.warning("pubsub: Reconnecting...")
                    self.webSocket.cancel()
                    self.setupWebsocket()
                    self.reconnectTime *= 2
                    self.reconnectTime = min(self.reconnectTime, 10 * 60)
                }
                return
            case .success(let message):
                switch message {
                case .string(let text):
                    logger.debug("pubsub: Received \(text)")
                    self.handleStringMessage(message: text)
                case .data(let data):
                    logger.error("pubsub: Received binary message: \(data)")
                @unknown default:
                    logger.warning("pubsub: Unknown message type.")
                }
                self.readMessage()
            }
        }
    }

    func sendMessage(message: String) {
        logger.debug("pubsub: Sending \(message)")
        let message = URLSessionWebSocketTask.Message.string(message)
        webSocket.send(message) { error in
            if let error = error {
                logger.error("pubsub: Failed to send message to server with error \(error)")
            }
        }
    }

    func sendPing() {
        sendMessage(message: "{\"type\":\"PING\"}")
        keepAliveTimer?.invalidate()
        keepAliveTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { _ in
            logger.warning("pubsub: Timeout waiting for pong. Reconnecting...")
            self.webSocket.cancel()
            self.setupWebsocket()
        }
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol proto: String?) {
        logger.info("pubsub: Connected to \(url)")
        reconnectTime = 2.0
        sendPing()
        sendMessage(message: "{\"type\":\"LISTEN\",\"data\":{\"topics\":[\"video-playback-by-id.\(channelId)\"]}}")
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        logger.warning("pubsub: Disconnect from server: \(String(describing: reason))")
    }

}
