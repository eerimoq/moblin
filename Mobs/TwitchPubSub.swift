import AVFoundation

struct MessageData: Decodable {
    var topic: String
    var message: String
}

struct Message: Decodable {
    var type: String
    var data: MessageData
}

struct Response : Decodable {
    var type: String
    var nonce: String
    var error: String
}

struct MessageViewCount : Decodable {
    var viewers: Int
}

extension String: Error {}

func getMessageType(message: String) throws -> String {
    if let jsonData = message.data(using: String.Encoding.utf8) {
        let data = try JSONSerialization.jsonObject(with: jsonData, options: JSONSerialization.ReadingOptions.mutableContainers)
        if let jsonResult: NSDictionary = data as? NSDictionary {
            if let type : String = jsonResult["type"] as? String {
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

final class TwitchPubSub: NSObject, URLSessionWebSocketDelegate {
    private var webSocket: URLSessionWebSocketTask?
    private var channelId: String?
    private var model: Model
    
    init(model: Model) {
        self.model = model
    }

    func start(channelId: String) {
        self.channelId = channelId
        let session = URLSession(configuration: .default,
                                 delegate: self,
                                 delegateQueue: OperationQueue())
        let url = URL(string: "wss://pubsub-edge.twitch.tv/v1")!
        webSocket = session.webSocketTask(with: url)
        webSocket?.resume()
        readMessage()
    }

    func handlePong() {
        print("Got pong.")
    }

    func handleResponse(message: String) throws {
        let message = try decodeResponse(message: message)
        print("Response:", message)
    }

    func handleMessage(message: String) throws {
        let message = try decodeMessage(message: message)
        let type = try getMessageType(message: message.data.message)
        if type == "viewcount" {
            let message = try decodeMessageViewCount(message: message.data.message)
            Task.detached(operation: {
                await MainActor.run {
                    self.model.numberOfViewers = "\(message.viewers)"
                }
            })
        } else {
            print("Unsupported message type:", type)
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
                print("Unsupported type:", type)
            }
        } catch {
            print("Failed to process message \"\(message)\" with error \(error)")
        }
    }

    func readMessage()  {
        webSocket?.receive { result in
            switch result {
            case .failure(let error):
                print("Failed to receive message:", error)
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleStringMessage(message: text)
                case .data(let data):
                    print("Received binary message:", data)
                @unknown default:
                    fatalError()
                }
                self.readMessage()
            }
        }
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol proto: String?) {
        print("Connected to PubSub server")
        sendMessage(message: "{\"type\":\"PING\"}")
        sendMessage(message: "{\"type\":\"LISTEN\",\"data\":{\"topics\":[\"video-playback-by-id.\(channelId!)\"]}}")
    }

    func sendMessage(message: String) {
        print("Sending:", message)
        let message = URLSessionWebSocketTask.Message.string(message)
        webSocket?.send(message) { error in
            if let error = error {
                print("WebSocket sending error:", error)
            }
        }
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("Disconnect from Server:", reason ?? "unknown")
    }

}
