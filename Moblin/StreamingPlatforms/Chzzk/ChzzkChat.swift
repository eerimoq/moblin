import Foundation

struct ChzzkChatMessage: Decodable {
    struct Profile: Decodable {
        let nickname: String
        let userRoleCode: String?
    }

    let channelId: String
    let senderChannelId: String
    let profile: Profile
    let content: String
    let emojis: [String: String]?
    private let role: String?

    var userRoleCode: String? {
        profile.userRoleCode ?? role
    }

    private enum CodingKeys: String, CodingKey {
        case channelId, senderChannelId, profile, content, emojis
        case role = "userRoleCode"
    }
}

struct ChzzkDonation: Decodable {
    let channelId: String
    let donatorChannelId: String?
    let donatorNickname: String?
    let donationText: String?
    let payAmount: String

    private enum CodingKeys: CodingKey {
        case channelId, donatorChannelId, donatorNickname, donationText, payAmount
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        channelId = try values.decode(String.self, forKey: .channelId)
        donatorChannelId = try values.decodeIfPresent(String.self, forKey: .donatorChannelId)
        donatorNickname = try values.decodeIfPresent(String.self, forKey: .donatorNickname)
        donationText = try values.decodeIfPresent(String.self, forKey: .donationText)
        if let amount = try? values.decode(Int.self, forKey: .payAmount) {
            payAmount = String(amount)
        } else {
            payAmount = try values.decode(String.self, forKey: .payAmount)
        }
    }
}

struct ChzzkSystemEvent: Decodable {
    struct Payload: Decodable {
        let sessionKey: String?
        let eventType: String?
    }

    let type: String
    let data: Payload
}

enum ChzzkEvent: Decodable {
    case system(ChzzkSystemEvent)
    case chat(ChzzkChatMessage)
    case donation(ChzzkDonation)
    case unknown

    init(from decoder: any Decoder) throws {
        var values = try decoder.unkeyedContainer()
        let name = try values.decode(String.self)
        func body<T: Decodable>() throws -> T {
            if let json = try? values.decode(String.self) {
                return try JSONDecoder().decode(T.self, from: Data(json.utf8))
            }
            return try values.decode(T.self)
        }
        switch name {
        case "SYSTEM":
            self = try .system(body())
        case "CHAT":
            self = try .chat(body())
        case "DONATION":
            self = try .donation(body())
        default:
            self = .unknown
        }
    }
}

private struct ChzzkHandshake: Decodable {
    let pingInterval: Int
    let pingTimeout: Int
}

@MainActor
final class ChzzkChat {
    private let api: ChzzkApi
    private let accessToken: @MainActor (Bool) async throws -> String
    private let onChat: (ChzzkChatMessage) -> Void
    private let onDonation: (ChzzkDonation) -> Void
    private var task: Task<Void, Never>?
    private var socket: URLSessionWebSocketTask?
    private let heartbeat = MainTimer()
    private let setupTimeout = MainTimer()
    private var handshake: ChzzkHandshake?
    private var chatSubscribed = false
    private var donationSubscribed = false

    init(api: ChzzkApi, accessToken: @escaping @MainActor (Bool) async throws -> String,
         onChat: @escaping (ChzzkChatMessage) -> Void, onDonation: @escaping (ChzzkDonation) -> Void)
    {
        self.api = api
        self.accessToken = accessToken
        self.onChat = onChat
        self.onDonation = onDonation
    }

    func start() {
        stop()
        task = Task {
            var delay = 2
            while !Task.isCancelled {
                do {
                    let token = try await accessToken(false)
                    do {
                        try await connect(token: token)
                    } catch ChzzkApiError.status(401) {
                        try Task.checkCancellation()
                        closeSocket()
                        let refreshed = try await accessToken(true)
                        try await connect(token: refreshed)
                    }
                } catch {
                    guard !Task.isCancelled else {
                        return
                    }
                    logger.debug("chzzk: Session disconnected")
                }
                if chatSubscribed || donationSubscribed {
                    delay = 2
                }
                closeSocket()
                try? await Task.sleep(for: .seconds(delay))
                delay = min(delay * 2, 60)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        closeSocket()
    }

    private func closeSocket() {
        setupTimeout.stop()
        heartbeat.stop()
        handshake = nil
        chatSubscribed = false
        donationSubscribed = false
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
    }

    func isChatConnected() -> Bool {
        chatSubscribed
    }

    func isDonationConnected() -> Bool {
        donationSubscribed
    }

    private func connect(token: String) async throws {
        let url = try await api.session(accessToken: token)
        try Task.checkCancellation()
        let connection = httpUrlSession().webSocketTask(with: url)
        socket = connection
        connection.resume()
        setupTimeout.startSingleShot(timeout: 30) {
            connection.cancel(with: .goingAway, reason: nil)
        }
        while true {
            let message = try await connection.receive()
            try Task.checkCancellation()
            guard case let .string(packet) = message else {
                continue
            }
            if packet.hasPrefix("42") {
                let data = Data(packet.dropFirst(2).utf8)
                if let event = try? JSONDecoder().decode(ChzzkEvent.self, from: data) {
                    try await handle(event, token: token)
                }
            } else if packet.hasPrefix("0") {
                let data = Data(packet.dropFirst().utf8)
                let settings = try JSONDecoder().decode(ChzzkHandshake.self, from: data)
                guard settings.pingInterval > 0, settings.pingTimeout > 0 else {
                    throw ChzzkApiError.invalidResponse
                }
                handshake = settings
                schedulePing(connection)
            } else if packet == "3" {
                schedulePing(connection)
            } else if packet == "1" || packet == "41" || packet.hasPrefix("44") {
                throw URLError(.networkConnectionLost)
            }
        }
    }

    private func schedulePing(_ connection: URLSessionWebSocketTask) {
        guard let handshake else {
            return
        }
        heartbeat.startSingleShot(timeout: Double(handshake.pingInterval) / 1000) { [weak self] in
            self?.heartbeat.startSingleShot(timeout: Double(handshake.pingTimeout) / 1000) {
                connection.cancel(with: .goingAway, reason: nil)
            }
            Task {
                do {
                    try await connection.send(.string("2"))
                } catch {
                    connection.cancel(with: .goingAway, reason: nil)
                }
            }
        }
    }

    private func handle(_ event: ChzzkEvent, token: String) async throws {
        switch event {
        case let .system(system):
            switch system.type {
            case "connected":
                guard let sessionKey = system.data.sessionKey, !sessionKey.isEmpty else {
                    throw ChzzkApiError.invalidResponse
                }
                for event in ["chat", "donation"] {
                    try Task.checkCancellation()
                    do {
                        try await api.subscribe(event, sessionKey: sessionKey, accessToken: token)
                    } catch ChzzkApiError.status(403) {
                        logger.debug("chzzk: Missing \(event) permission")
                    }
                }
            case "subscribed", "unsubscribed", "revoked":
                let subscribed = system.type == "subscribed"
                if system.data.eventType == "CHAT" {
                    chatSubscribed = subscribed
                } else if system.data.eventType == "DONATION" {
                    donationSubscribed = subscribed
                }
                if chatSubscribed || donationSubscribed {
                    setupTimeout.stop()
                }
            default:
                break
            }
        case let .chat(message):
            onChat(message)
        case let .donation(donation):
            onDonation(donation)
        case .unknown:
            break
        }
    }
}
