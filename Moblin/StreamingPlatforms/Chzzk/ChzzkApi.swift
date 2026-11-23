import Foundation

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

private struct ChzzkLives: Decodable {
    struct Live: Decodable {
        let channelId: String
        let concurrentUserCount: Int
    }

    struct Page: Decodable {
        let next: String?
    }

    let data: [Live]
    let page: Page?
}

@MainActor
final class ChzzkApi {
    private let clientId: String
    private let clientSecret: String
    private var viewerChannelId: String?
    private var viewerCursor: String?
    private var viewerPageMatched = false

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

    func viewers(channelId: String) async throws -> Int? {
        if viewerChannelId != channelId {
            viewerChannelId = channelId
            viewerCursor = nil
            viewerPageMatched = false
        }
        for page in 0 ..< 5 {
            if page > 0 {
                try await Task.sleep(for: .seconds(1))
            }
            let cursor = viewerCursor
            var query = [URLQueryItem(name: "size", value: "20")]
            if let cursor {
                query.append(URLQueryItem(name: "next", value: cursor))
            }
            let lives: ChzzkLives
            do {
                lives = try await content(path: "/open/v1/lives", query: query, clientAuth: true)
            } catch ChzzkApiError.status(400) where cursor != nil {
                viewerCursor = nil
                viewerPageMatched = false
                continue
            }
            try Task.checkCancellation()
            if let live = lives.data.first(where: { $0.channelId == channelId }) {
                viewerPageMatched = true
                return live.concurrentUserCount
            }
            if viewerPageMatched, cursor != nil {
                viewerCursor = nil
                viewerPageMatched = false
                continue
            }
            viewerPageMatched = false
            viewerCursor = lives.page?.next
            if viewerCursor == nil || viewerCursor == "" || viewerCursor == cursor {
                viewerCursor = nil
                break
            }
        }
        return nil
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
                                       query: [URLQueryItem] = [], accessToken: String? = nil,
                                       clientAuth: Bool = false) async throws -> T
    {
        guard let result: T = try await request(path: path, method: method, body: body, query: query,
                                                accessToken: accessToken, clientAuth: clientAuth)
        else {
            throw ChzzkApiError.invalidResponse
        }
        return result
    }

    private func request<T: Decodable>(path: String, method: String, body: [String: String]? = nil,
                                       query: [URLQueryItem] = [], accessToken: String? = nil,
                                       clientAuth: Bool = false) async throws -> T?
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
        if clientAuth {
            request.setValue(clientId, forHTTPHeaderField: "Client-Id")
            request.setValue(clientSecret, forHTTPHeaderField: "Client-Secret")
        }
        if let body {
            request.httpBody = try JSONEncoder().encode(body)
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
