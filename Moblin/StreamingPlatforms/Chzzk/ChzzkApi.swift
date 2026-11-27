import Foundation

func isValidChzzkChannelId(_ id: String) -> Bool {
    id.count == 32 && id.allSatisfy { $0.isHexDigit && $0.isASCII }
}

struct ChzzkTokens: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
}

struct ChzzkUser: Decodable {
    let channelId: String
    let channelName: String
}

enum ChzzkApiError: Error {
    case status(Int)
    case invalidResponse
}

enum ChzzkChatSendError: Error {
    case emptyMessage
    case messageTooLong
}

func prepareChzzkChatMessage(_ message: String, isBotReply: Bool) throws -> String {
    var text = message.trim()
    guard !text.isEmpty else {
        throw ChzzkChatSendError.emptyMessage
    }
    if isBotReply, text.hasPrefix("!") {
        text = "↪ \(text)"
    }
    guard text.utf16.count > 100 else {
        return text
    }
    guard isBotReply else {
        throw ChzzkChatSendError.messageTooLong
    }
    var length = 0
    let prefix = text.prefix { character in
        length += String(character).utf16.count
        return length < 100
    }
    return "\(prefix)…"
}

private struct ChzzkResponse<Content: Decodable>: Decodable {
    let code: Int
    let content: Content?
}

private struct ChzzkEmpty: Decodable {}

private struct ChzzkChatSendResponse: Decodable {
    let messageId: String
}

struct ChzzkTokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int

    private enum CodingKeys: CodingKey {
        case accessToken, refreshToken, expiresIn
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        accessToken = try values.decode(String.self, forKey: .accessToken)
        refreshToken = try values.decode(String.self, forKey: .refreshToken)
        if let seconds = try? values.decode(Int.self, forKey: .expiresIn) {
            expiresIn = seconds
        } else {
            let text = try values.decode(String.self, forKey: .expiresIn)
            guard let seconds = Int(text) else {
                throw ChzzkApiError.invalidResponse
            }
            expiresIn = seconds
        }
    }
}

private struct ChzzkSession: Decodable {
    let url: URL
}

struct ChzzkLiveStatus: Decodable {
    let status: String
    let concurrentUserCount: Int?

    func platformStatus() throws -> PlatformStatus {
        switch status {
        case "OPEN":
            guard let concurrentUserCount, concurrentUserCount >= 0 else {
                throw ChzzkApiError.invalidResponse
            }
            return .live(viewerCount: concurrentUserCount)
        case "CLOSE", "CLOSED":
            return .offline
        default:
            throw ChzzkApiError.invalidResponse
        }
    }
}

private struct ChzzkChannelStatus: Decodable {
    let channelId: String
    let openLive: Bool
}

private struct ChzzkPublicResponse<Content: Decodable>: Decodable {
    let code: Int
    let content: Content
}

struct ChzzkModerationTarget: Sendable {
    let channelId: String
    let senderChannelId: String
    let chatChannelId: String?
    let messageTime: Int64?

    func supports(_ action: ChzzkModerationAction) -> Bool {
        guard !senderChannelId.isEmpty else {
            return false
        }
        switch action {
        case .restrict, .unrestrict:
            return true
        case .temporaryRestrict, .temporaryUnrestrict:
            return chatChannelId?.isEmpty == false
        case .hideMessage:
            return chatChannelId?.isEmpty == false && (messageTime ?? 0) > 0
        }
    }

    var messageId: String? {
        guard let chatChannelId, let messageTime else {
            return nil
        }
        return "chzzk:\(channelId):\(chatChannelId):\(senderChannelId):\(messageTime)"
    }
}

enum ChzzkModerationAction: Equatable {
    case restrict
    case unrestrict
    case temporaryRestrict
    case temporaryUnrestrict
    case hideMessage
}

@MainActor
final class ChzzkApi {
    private let clientId: String
    private let clientSecret: String

    init(clientId: String, clientSecret: String) {
        self.clientId = clientId
        self.clientSecret = clientSecret
    }

    func authorizationUrl(redirectUri: String, state: String) -> URL {
        var url = URLComponents(string: "https://chzzk.naver.com/account-interlock")!
        url.queryItems = [
            URLQueryItem(name: "clientId", value: clientId),
            URLQueryItem(name: "redirectUri", value: redirectUri),
            URLQueryItem(name: "state", value: state),
        ]
        url.percentEncodedQuery = url.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        return url.url!
    }

    func exchange(code: String, state: String) async throws -> ChzzkTokens {
        try await tokens(["grantType": "authorization_code", "code": code, "state": state])
    }

    func refresh(refreshToken: String) async throws -> ChzzkTokens {
        try await tokens(["grantType": "refresh_token", "refreshToken": refreshToken])
    }

    private func tokens(_ grant: [String: String]) async throws -> ChzzkTokens {
        var body = grant
        body["clientId"] = clientId
        body["clientSecret"] = clientSecret
        let response: ChzzkTokenResponse = try await content(path: "/auth/v1/token",
                                                             method: "POST", body: body)
        guard !response.accessToken.isEmpty, !response.refreshToken.isEmpty, response.expiresIn > 0 else {
            throw ChzzkApiError.invalidResponse
        }
        return ChzzkTokens(accessToken: response.accessToken, refreshToken: response.refreshToken,
                           expiresAt: Date().addingTimeInterval(Double(response.expiresIn)))
    }

    func revoke(refreshToken: String) async throws {
        _ = try await request(path: "/auth/v1/token/revoke", method: "POST", body: [
            "clientId": clientId,
            "clientSecret": clientSecret,
            "token": refreshToken,
            "tokenTypeHint": "refresh_token",
        ]) as ChzzkEmpty?
    }

    func user(accessToken: String) async throws -> ChzzkUser {
        try await content(path: "/open/v1/users/me", accessToken: accessToken)
    }

    static func liveStatus(channelId: String,
                           get: (URLRequest) async throws -> (Data, HTTPURLResponse) = httpGet(request:))
        async throws -> PlatformStatus
    {
        guard isValidChzzkChannelId(channelId) else {
            throw ChzzkApiError.invalidResponse
        }
        func fetch<T: Decodable>(_ path: String) async throws -> T {
            var request = URLRequest(url: URL(string: "https://api.chzzk.naver.com\(path)")!)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 15
            let (data, response) = try await get(request)
            guard response.statusCode == 200 else {
                throw ChzzkApiError.status(response.statusCode)
            }
            let envelope = try JSONDecoder().decode(ChzzkPublicResponse<T>.self, from: data)
            guard envelope.code == 200 else {
                throw ChzzkApiError.status(envelope.code)
            }
            return envelope.content
        }
        if let live: ChzzkLiveStatus = try await fetch("/polling/v2/channels/\(channelId)/live-status") {
            return try live.platformStatus()
        }
        let channel: ChzzkChannelStatus = try await fetch("/service/v1/channels/\(channelId)")
        guard channel.channelId == channelId, !channel.openLive else {
            throw ChzzkApiError.invalidResponse
        }
        return .offline
    }

    func moderate(_ action: ChzzkModerationAction, target: ChzzkModerationTarget,
                  accessToken: String) async throws
    {
        guard target.supports(action) else {
            throw ChzzkApiError.invalidResponse
        }
        let path: String
        let method: String
        var body: [String: Any] = ["targetChannelId": target.senderChannelId]
        switch action {
        case .restrict:
            path = "/open/v1/restrict-channels"
            method = "POST"
        case .unrestrict:
            path = "/open/v1/restrict-channels"
            method = "DELETE"
        case .temporaryRestrict, .temporaryUnrestrict:
            guard let chatChannelId = target.chatChannelId, !chatChannelId.isEmpty else {
                throw ChzzkApiError.invalidResponse
            }
            path = "/open/v1/temporary-restrict-channels"
            method = action == .temporaryRestrict ? "POST" : "DELETE"
            body["chatChannelId"] = chatChannelId
        case .hideMessage:
            guard let chatChannelId = target.chatChannelId, !chatChannelId.isEmpty,
                  let messageTime = target.messageTime
            else {
                throw ChzzkApiError.invalidResponse
            }
            path = "/open/v1/chats/blind-message"
            method = "POST"
            body = ["chatChannelId": chatChannelId, "messageTime": messageTime,
                    "senderChannelId": target.senderChannelId]
        }
        _ = try await request(path: path, method: method, accessToken: accessToken,
                              bodyData: JSONSerialization.data(withJSONObject: body)) as ChzzkEmpty?
    }

    func session(accessToken: String) async throws -> URL {
        let session: ChzzkSession = try await content(path: "/open/v1/sessions/auth",
                                                      accessToken: accessToken)
        guard var url = URLComponents(url: session.url, resolvingAgainstBaseURL: false),
              let scheme = url.scheme, ["https", "wss"].contains(scheme), url.host != nil
        else {
            throw ChzzkApiError.invalidResponse
        }
        url.scheme = "wss"
        url.path = "/socket.io/"
        var items = (url.queryItems ?? []).filter { !["EIO", "transport"].contains($0.name) }
        items.append(URLQueryItem(name: "EIO", value: "3"))
        items.append(URLQueryItem(name: "transport", value: "websocket"))
        url.queryItems = items
        url.percentEncodedQuery = url.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        guard let socketUrl = url.url else {
            throw ChzzkApiError.invalidResponse
        }
        return socketUrl
    }

    func subscribe(_ event: String, sessionKey: String, accessToken: String) async throws {
        _ = try await request(path: "/open/v1/sessions/events/subscribe/\(event)", method: "POST",
                              query: [URLQueryItem(name: "sessionKey", value: sessionKey)],
                              accessToken: accessToken) as ChzzkEmpty?
    }

    func sendChatMessage(message: String, accessToken: String) async throws {
        let _: ChzzkChatSendResponse = try await content(path: "/open/v1/chats/send",
                                                         method: "POST",
                                                         body: ["message": message],
                                                         accessToken: accessToken)
    }

    private func content<T: Decodable>(path: String, method: String = "GET", body: [String: String]? = nil,
                                       query: [URLQueryItem] = [],
                                       accessToken: String? = nil) async throws -> T
    {
        guard let result: T = try await request(path: path, method: method, body: body, query: query,
                                                accessToken: accessToken)
        else {
            throw ChzzkApiError.invalidResponse
        }
        return result
    }

    private func request<T: Decodable>(path: String, method: String, body: [String: String]? = nil,
                                       query: [URLQueryItem] = [], accessToken: String? = nil,
                                       bodyData: Data? = nil) async throws -> T?
    {
        var url = URLComponents(string: "https://openapi.chzzk.naver.com")!
        url.path = path
        if !query.isEmpty {
            url.queryItems = query
            url.percentEncodedQuery = url.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        }
        var request = URLRequest(url: url.url!)
        request.httpMethod = method
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        if let bodyData {
            request.httpBody = bodyData
        }
        let (data, response) = try await httpGet(request: request)
        guard response.isSuccessful else {
            throw ChzzkApiError.status(response.statusCode)
        }
        if data.isEmpty {
            return nil
        }
        let envelope = try JSONDecoder().decode(ChzzkResponse<T>.self, from: data)
        guard (200 ..< 300).contains(envelope.code) else {
            throw ChzzkApiError.status(envelope.code)
        }
        return envelope.content
    }
}
