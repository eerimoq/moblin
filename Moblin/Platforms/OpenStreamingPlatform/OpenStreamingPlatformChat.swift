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

private struct IqBind: Codable {
    var jid: String
}

private struct Iq: Codable {
    var bind: IqBind
}

// periphery:ignore
private struct IqContainer: Codable {
    let iq: Iq
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
    private let channelId: String
    private var authenticated = false
    private var jid: String = ""

    init(model: Model, url: String, username: String, password: String, channelId: String) {
        self.model = model
        self.url = url
        self.username = username
        self.password = password
        self.channelId = channelId
        let url = URL(string: "ws://192.168.50.72:5443/ws")!
        webSocket = URLSession(configuration: .default).webSocketTask(with: url)
    }

    func start() {
        stop()
        logger.debug("open-streaming-platform: start")
        task = Task.init {
            while true {
                do {
                    try await setupConnection()
                    try await sendOpen()
                    try await receiveMessages()
                } catch {
                    logger.debug("open-streaming-platform: error: \(error)")
                }
                if Task.isCancelled {
                    logger.debug("open-streaming-platform: Cancelled")
                    connected = false
                    break
                }
                logger.debug("open-streaming-platform: Disconnected")
                connected = false
                try await sleep(seconds: 5)
                logger.debug("open-streaming-platform: Reconnecting")
            }
        }
    }

    func stop() {
        logger.debug("open-streaming-platform: stop")
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
        logger.debug("open-streaming-platform: URL \(url)")
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
                logger.debug("open-streaming-platform: ???")
            }
        }
    }

    private func handleMessage(message: String) async throws {
        logger.debug("open-streaming-platform: Got string \(message)")
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
            let message = try XMLDecoder().decode(IqContainer.self, from: data)
            try await handleMessageIq(message: message.iq)
            return
        } catch {}
        do {
            let decoder = XMLDecoder()
            decoder.shouldProcessNamespaces = true
            let message = try decoder.decode(FeaturesContainer.self, from: data)
            try await handleMessageFeatures(message: message.features)
            return
        } catch {}
        logger.debug("open-streaming-platform: Ignoring message \(message)")
    }

    private func handleMessageOpen(message _: Open) async throws {
        logger.debug("open-streaming-platform: handle open")
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

    private func handleMessageIq(message: Iq) async throws {
        jid = message.bind.jid
        logger.debug("open-streaming-platform: Got JID \(jid)")
        try await sendPresence()
    }

    private func handleMessageSuccess() async throws {
        logger.debug("open-streaming-platform: handle success")
        authenticated = true
        connected = true
        try await sendOpen()
    }

    private func handleMessageFeatures(message _: Features) async throws {
        logger.debug("open-streaming-platform: handle features")
        if authenticated {
            try await sendString(message:
                """
                <iq id=\"_bind_auth_2\" type=\"set\" xmlns=\"jabber:client\">\
                <bind xmlns=\"urn:ietf:params:xml:ns:xmpp-bind\"/></iq>
                """)
            try await sendString(message:
                """
                <iq id=\"_session_auth_2\" type=\"set\" xmlns=\"jabber:client\">\
                <session xmlns=\"urn:ietf:params:xml:ns:xmpp-session\"/></iq>
                """)
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
                to: "osp.internal",
                from: nil,
                version: "1.0",
                id: nil
            )
        )
    }

    private func sendPresence() async throws {
        try await sendString(
            message: """
            <presence
               from=\"\(jid)\"
               to=\"\(channelId)@conference.osp.internal/\(username)\"
               xmlns=\"jabber:client\">
              <x xmlns=\"http://jabber.org/protocol/muc\"/>
            </presence>
            """
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
        try await sendString(message: message)
    }

    private func sendString(message: String) async throws {
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
