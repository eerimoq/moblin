import Foundation
import XMLCoder

private struct Message: Codable {
    let from: String
    let body: String

    func user() -> String? {
        guard let slashIndex = from.firstIndex(of: "/") else {
            return nil
        }
        return String(from.suffix(from: from.index(slashIndex, offsetBy: 1)))
    }
}

private struct MessageContainer: Codable {
    let message: Message
}

// periphery:ignore
private struct Open: Codable, DynamicNodeEncoding {
    let xmlns: String
    let to: String?
    let from: String?
    let version: String
    let id: String?

    static func nodeEncoding(for _: CodingKey) -> XMLEncoder.NodeEncoding {
        return .attribute
    }
}

private struct OpenContainer: Codable {
    let open: Open
}

private struct Success: Codable {}

// periphery:ignore
private struct SuccessContainer: Codable {
    let success: Success
}

// periphery:ignore
private struct Auth: Codable, DynamicNodeEncoding {
    let xmlns: String
    let mechanism: String
    let value: String

    enum CodingKeys: String, CodingKey {
        case xmlns
        case mechanism
        case value = ""
    }

    static func nodeEncoding(for key: CodingKey) -> XMLEncoder.NodeEncoding {
        switch key {
        case CodingKeys.value:
            return .element
        default:
            return .attribute
        }
    }
}

// periphery:ignore
private struct Mechanisms: Codable {
    let mechanism: [String]
}

// periphery:ignore
private struct Features: Codable {
    let mechanisms: Mechanisms?
}

private struct FeaturesContainer: Codable {
    let features: Features
}

class OpenStreamingPlatformChat {
    private var model: Model
    private var task: Task<Void, Error>?
    private var connected: Bool = false
    private var webSocket: URLSessionWebSocketTask
    private let url: String
    private let username: String
    private let password: String
    private var authenticated = false

    init(model: Model, url: String, username: String, password: String) {
        self.model = model
        self.url = url
        self.username = username
        self.password = password
        let url = URL(string: "ws://192.168.50.72:5443/ws")!
        webSocket = URLSession(configuration: .default).webSocketTask(with: url)
    }

    func start() {
        stop()
        logger.info("open-streaming-platform: start")
        task = Task.init {
            while true {
                do {
                    try await setupConnection()
                    try await sendOpen()
                    try await receiveMessages()
                } catch {
                    logger.error("open-streaming-platform: error: \(error)")
                }
                if Task.isCancelled {
                    logger.info("open-streaming-platform: Cancelled")
                    connected = false
                    break
                }
                logger.info("open-streaming-platform: Disconnected")
                connected = false
                try await Task.sleep(nanoseconds: 5_000_000_000)
                logger.info("open-streaming-platform: Reconnecting")
            }
        }
    }

    func stop() {
        logger.info("open-streaming-platform: stop")
        task?.cancel()
        task = nil
    }

    func isConnected() -> Bool {
        return connected
    }

    func hasEmotes() -> Bool {
        return true
    }

    private func setupConnection() async throws {
        authenticated = false
        guard let url = URL(string: url) else {
            throw "Faield to create URL"
        }
        logger.info("open-streaming-platform: URL \(url)")
        webSocket = URLSession.shared.webSocketTask(
            with: url,
            protocols: ["xmpp"]
        )
        webSocket.resume()
    }

    private func receiveMessages() async throws {
        while true {
            let message = try await webSocket.receive()
            if Task.isCancelled {
                break
            }
            switch message {
            case let .string(message):
                try await handleMessage(message: message)
            default:
                logger.info("open-streaming-platform: ???")
            }
        }
    }

    private func handleMessage(message: String) async throws {
        logger.info("open-streaming-platform: Got string \(message)")
        guard let data = "<container>\(message)</container>".data(using: .utf8) else {
            return
        }
        do {
            let message = try XMLDecoder().decode(MessageContainer.self, from: data)
            try await handleMessageMessage(message: message.message)
            return
        } catch {}
        do {
            let message = try XMLDecoder().decode(OpenContainer.self, from: data)
            try await handleMessageOpen(message: message.open)
            return
        } catch {}
        do {
            _ = try XMLDecoder().decode(SuccessContainer.self, from: data)
            try await handleMessageSuccess()
            return
        } catch {}
        do {
            let decoder = XMLDecoder()
            decoder.shouldProcessNamespaces = true
            let message = try decoder.decode(FeaturesContainer.self, from: data)
            try await handleMessageFeatures(message: message.features)
            return
        } catch {}
        logger.info("open-streaming-platform: Ignoring message \(message)")
    }

    private func handleMessageOpen(message _: Open) async throws {
        logger.info("open-streaming-platform: handle open")
    }

    private func handleMessageMessage(message: Message) async throws {
        let segments = createSegments(message: message.body)
        await MainActor.run {
            model.appendChatMessage(user: message.user() ?? "unknown",
                                    userColor: nil,
                                    segments: segments,
                                    timestamp: model.digitalClock,
                                    timestampDate: Date(),
                                    isAction: false,
                                    isAnnouncement: false,
                                    isFirstMessage: false)
        }
    }

    private func handleMessageSuccess() async throws {
        logger.info("open-streaming-platform: handle success")
        authenticated = true
        connected = true
        try await sendOpen()
    }

    private func handleMessageFeatures(message _: Features) async throws {
        logger.info("open-streaming-platform: handle features")
        if authenticated {
            try await webSocket.send(.string(
                """
                <iq id=\"_bind_auth_2\" type=\"set\" xmlns=\"jabber:client\">\
                <bind xmlns=\"urn:ietf:params:xml:ns:xmpp-bind\"/></iq>
                """
            ))
            try await webSocket.send(.string(
                """
                <iq id=\"_session_auth_2\" type=\"set\" xmlns=\"jabber:client\">\
                <session xmlns=\"urn:ietf:params:xml:ns:xmpp-session\"/></iq>
                """
            ))
        } else {
            guard let value = packPlainAuth() else {
                return
            }
            try await sendAuth(value: value, mechanism: "PLAIN")
        }
    }

    private func sendOpen() async throws {
        try await send(
            root: "open",
            data: Open(
                xmlns: "urn:ietf:params:xml:ns:xmpp-framing",
                to: "localhost",
                from: nil,
                version: "1.0",
                id: nil
            )
        )
    }

    private func sendAuth(value: String, mechanism: String) async throws {
        try await send(
            root: "auth",
            data: Auth(
                xmlns: "urn:ietf:params:xml:ns:xmpp-sasl",
                mechanism: mechanism,
                value: value
            )
        )
    }

    private func send(root: String, data: Encodable) async throws {
        let message = try XMLEncoder().encode(data, withRootKey: root)
        guard let message = String(bytes: message, encoding: .utf8) else {
            return
        }
        // logger.info("open-streaming-platform: Sending \(message)")
        try await webSocket.send(.string(message))
    }

    private func packPlainAuth() -> String? {
        var data = Data()
        data.append(0)
        data.append(contentsOf: username.utf8)
        data.append(0)
        data.append(contentsOf: password.utf8)
        return String(data: data.base64EncodedData(), encoding: .utf8)
    }

    private func createSegments(message: String) -> [ChatPostSegment] {
        return makeChatPostTextSegments(text: message)
    }
}
