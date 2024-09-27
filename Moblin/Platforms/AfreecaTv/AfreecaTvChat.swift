import Foundation

private enum MessageKind: Int {
    case null = 0
    case one = 1
    case two = 2
    case join = 4
    case post = 5
    case a = 54
    case b = 90
    case c = 94
    case image = 109
    case d = 87 // club member?
    case e = 12 // club member?
}

// image
// https://ogq-sticker-global-cdn-z01.afreecatv.com/sticker/16f23d102576058/5_80.png?ver=1
// parts[2] = 16f23d102576058
// parts[3] = 5
// parts[11] = png
// patts[12] = 1

private func packMessage(kind: MessageKind, parts: [String]) -> Data {
    var payload = "\u{0c}"
    payload += parts.joined(separator: "\u{0c}")
    if !parts.isEmpty {
        payload += "\u{0c}"
    }
    var message = String(format: "\u{1b}\t%04d%06d00", kind.rawValue, payload.count)
    message += payload
    return message.data(using: .utf8)!
}

private func unpackMessage(message: Data) throws -> (MessageKind?, [String]) {
    guard let message = String(bytes: message, encoding: .utf8) else {
        throw "Bad message not UTF-8"
    }
    guard message.count > 14 else {
        throw "Message too short"
    }
    var startIndex = message.index(message.startIndex, offsetBy: 2)
    let stopIndex = message.index(message.startIndex, offsetBy: 6)
    guard let value = Int(message[startIndex ..< stopIndex]) else {
        throw "Bad kind"
    }
    guard let kind = MessageKind(rawValue: value) else {
        logger.debug("afreecatv: Unknown kind \(value)")
        return (nil, [])
    }
    startIndex = message.index(message.startIndex, offsetBy: 14)
    let payload = message[startIndex...]
    return (
        kind,
        String(payload).trimmingCharacters(in: CharacterSet(charactersIn: "\u{0c}"))
            .components(separatedBy: "\u{0c}")
    )
}

struct PlayerLiveChannel: Codable {
    var chdomain: String
    var chpt: String
    var chatno: String
    var ftk: String

    private enum CodingKeys: String, CodingKey {
        case chdomain = "CHDOMAIN"
        case chpt = "CHPT"
        case chatno = "CHATNO"
        case ftk = "FTK"
    }
}

struct PlayerLiveResponse: Codable {
    var channel: PlayerLiveChannel

    private enum CodingKeys: String, CodingKey {
        case channel = "CHANNEL"
    }
}

final class AfreecaTvChat: NSObject {
    private var model: Model
    private var channelName: String
    private var streamId: String
    private var task: Task<Void, Error>?
    private var connected: Bool = false
    private var webSocket: URLSessionWebSocketTask
    private var emotes: Emotes
    private var keepAliveTask: Task<Void, Error>?

    init(model: Model, channelName: String, streamId: String) {
        self.model = model
        self.channelName = channelName
        self.streamId = streamId
        emotes = Emotes()
        let url = URL(string: "wss://foo.com")!
        webSocket = URLSession(configuration: .default).webSocketTask(with: url)
    }

    private func makeWebSocketUrl(chdomain: String, chpt: String) -> URL? {
        guard let chpt = Int(chpt) else {
            return nil
        }
        return URL(string: "wss://\(chdomain):\(chpt + 1)/Websocket/\(channelName)")
    }

    private func sendOne() async throws {
        try await webSocket.send(.data(packMessage(kind: .one, parts: ["", "", "16"])))
    }

    private func sendTwo(chatno: String, ftk: String) async throws {
        try await webSocket.send(.data(packMessage(kind: .two, parts: [
            chatno,
            ftk,
            "0",
            "",
            """
            log\u{11}\u{06}&\u{06}\
            set_bps\u{06}=\u{06}8000\u{06}&\u{06}\
            view_bps\u{06}=\u{06}1000\u{06}&\u{06}\
            quality\u{06}=\u{06}normal\u{06}&\u{06}\
            uuid\u{06}=\u{06}1e43cf6d37913c36b35d580e0b5656ec\u{06}&\u{06}\
            geo_cc\u{06}=\u{06}KR\u{06}&\u{06}\
            geo_rc\u{06}=\u{06}11\u{06}&\u{06}\
            acpt_lang\u{06}=\u{06}ko_KR\u{06}&\u{06}\
            svc_lang\u{06}=\u{06}ko_KR\u{12}\
            pwd\u{11}\u{12}\
            auth_info\u{11}NULL\u{12}\
            pver\u{11}1\u{12}\
            access_system\u{11}html5\u{12}
            """,
        ])))
    }

    func start() {
        stop()
        logger.debug("afreecatv: start")
        task = Task.init {
            while true {
                do {
                    let info = try await getChannelInfo()
                    try await setupConnection(info: info)
                    setupKeepAlive()
                    try await receiveMessages(info: info)
                } catch {
                    logger.debug("afreecatv: error: \(error)")
                }
                if Task.isCancelled {
                    logger.debug("afreecatv: Cancelled")
                    connected = false
                    break
                }
                logger.debug("afreecatv: Disconnected")
                connected = false
                try await sleep(seconds: 5)
                logger.debug("afreecatv: Reconnecting")
            }
        }
    }

    func stop() {
        logger.debug("afreecatv: stop")
        keepAliveTask?.cancel()
        keepAliveTask = nil
        task?.cancel()
        task = nil
    }

    func isConnected() -> Bool {
        return connected
    }

    func hasEmotes() -> Bool {
        return true
    }

    private func setupConnection(info: PlayerLiveChannel) async throws {
        guard let url = makeWebSocketUrl(chdomain: info.chdomain, chpt: info.chpt) else {
            throw "Faield to create URL"
        }
        logger.debug("afreecatv: URL \(url)")
        webSocket = URLSession.shared.webSocketTask(
            with: url,
            protocols: ["chat"]
        )
        webSocket.resume()
        try await sendOne()
    }

    private func setupKeepAlive() {
        keepAliveTask = Task.init {
            let message = packMessage(kind: .null, parts: [])
            while !Task.isCancelled {
                try await sleep(seconds: 60)
                logger.debug("afreecatv: Sending keep alive")
                try await webSocket.send(.data(message))
            }
        }
    }

    private func receiveMessages(info: PlayerLiveChannel) async throws {
        while true {
            let message = try await webSocket.receive()
            if Task.isCancelled {
                break
            }
            switch message {
            case let .data(message):
                let (kind, parts) = try unpackMessage(message: message)
                if let kind {
                    if kind != .join {
                        logger.debug("afreecatv: Got \(kind) \(parts)")
                    }
                } else {
                    logger.debug("afreecatv: Got \(parts)")
                }
                switch kind {
                case .one:
                    logger.debug("afreecatv: Connected?")
                    connected = true
                    try await sendTwo(chatno: info.chatno, ftk: info.ftk)
                case .post:
                    await handlePostMessage(parts: parts)
                default:
                    break
                }
            case let .string(message):
                logger.debug("afreecatv: Got string \(message)")
            default:
                logger.debug("afreecatv: ???")
            }
        }
    }

    private func handlePostMessage(parts: [String]) async {
        guard parts.count > 5 else {
            logger.error("afreecatv: Bad post length")
            return
        }
        let user = parts[5]
        let segments = createSegments(message: parts[0])
        await MainActor.run {
            self.model.appendChatMessage(
                platform: .afreecaTv,
                user: user,
                userColor: nil,
                userBadges: [],
                segments: segments,
                timestamp: model.digitalClock,
                timestampTime: .now,
                isAction: false,
                isSubscriber: false,
                isModerator: false,
                highlight: nil
            )
        }
    }

    private func getChannelInfo() async throws -> PlayerLiveChannel {
        guard let url =
            URL(string: "https://live.afreecatv.com/afreeca/player_live_api.php?bjid=\(channelName)")
        else {
            throw "Invalid URL"
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = Data("""
        bid=\(channelName)&bno=\(streamId)&type=live&confirm_adult=false\
        &player_type=html5&mode=landing&from_api=0&pwd=&stream_type=common&quality=HD
        """.utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response.http else {
            throw "Not an HTTP response"
        }
        if !response.isSuccessful {
            throw "Not successful"
        }
        return try JSONDecoder().decode(PlayerLiveResponse.self, from: data).channel
    }

    private func createSegments(message: String) -> [ChatPostSegment] {
        var segments: [ChatPostSegment] = []
        var id = 0
        for var segment in makeChatPostTextSegments(text: message, id: &id) {
            if let text = segment.text {
                segments += emotes.createSegments(text: text, id: &id)
                segment.text = nil
            }
            if segment.text != nil || segment.url != nil {
                segments.append(segment)
            }
        }
        return segments
    }
}
