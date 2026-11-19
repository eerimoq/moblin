import Foundation

let chzzkRedirectUri = "http://localhost:8080/chzzk/callback"

struct ChzzkLoginRequest {
    let streamId: UUID
    let state: String
    let url: URL

    func code(from url: URL) -> String? {
        guard var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        let items = parts.queryItems ?? []
        parts.query = nil
        let codes = items.filter { $0.name == "code" }
        guard parts.string == chzzkRedirectUri,
              items.filter({ $0.name == "state" }).map(\.value) == [state],
              codes.count == 1, let code = codes.first?.value, !code.isEmpty
        else {
            return nil
        }
        return code
    }
}

struct ChzzkAccount: Codable {
    var clientId = ""
    var clientSecret = ""
    var channelId: String?
    var tokens: ChzzkTokens?

    private static var keychain: Keychain {
        Keychain(streamId: "account", server: "openapi.chzzk.naver.com", logPrefix: "chzzk: auth")
    }

    static func load() -> Self {
        guard let value = keychain.load(), let account = try? JSONDecoder().decode(
            Self.self,
            from: Data(value.utf8)
        )
        else {
            return Self()
        }
        return account
    }

    func store() {
        if clientId.isEmpty, clientSecret.isEmpty {
            Self.keychain.remove()
        } else if let data = try? JSONEncoder().encode(self),
                  let value = String(data: data, encoding: .utf8)
        {
            Self.keychain.store(value: value)
        }
    }
}

extension Model {
    var chzzkClientId: String {
        chzzkAccount.clientId
    }

    var chzzkClientSecret: String {
        chzzkAccount.clientSecret
    }

    var chzzkApi: ChzzkApi? {
        guard !chzzkClientId.isEmpty, !chzzkClientSecret.isEmpty else {
            return nil
        }
        return ChzzkApi(clientId: chzzkClientId, clientSecret: chzzkClientSecret)
    }

    var chzzkAuthorizedChannelId: String? {
        chzzkAccount.channelId
    }

    var chzzkLoggedIn: Bool {
        chzzkAccount.tokens != nil && chzzkAuthorizedChannelId == stream.chzzkChannelId
    }

    func chzzkCredentialsUpdated(clientId: String, clientSecret: String) {
        let clientId = clientId.trim()
        let clientSecret = clientSecret.trim()
        guard clientId != chzzkClientId || clientSecret != chzzkClientSecret else {
            return
        }
        cancelChzzkAuth()
        chzzkAccount = ChzzkAccount(clientId: clientId, clientSecret: clientSecret)
        chzzkAccount.store()
        chzzkChannelUpdated()
    }

    private func cancelChzzkAuth() {
        chzzkLoginRequest = nil
        chzzkPresentingLogin = false
        chzzkRefreshTask?.cancel()
        chzzkRefreshTask = nil
    }

    func chzzkSignIn() {
        guard let api = chzzkApi else {
            return
        }
        let state = UUID().uuidString
        chzzkLoginRequest = ChzzkLoginRequest(streamId: stream.id, state: state,
                                              url: api.authorizationUrl(
                                                  redirectUri: chzzkRedirectUri,
                                                  state: state
                                              ))
        chzzkPresentingLogin = true
    }

    func chzzkLoginCompleted(url: URL?) {
        guard chzzkPresentingLogin, let request = chzzkLoginRequest, let api = chzzkApi else {
            return
        }
        chzzkPresentingLogin = false
        guard let url, let code = request.code(from: url) else {
            chzzkLoginRequest = nil
            makeErrorToast(title: String(localized: "CHZZK login failed"))
            return
        }
        Task {
            defer {
                if chzzkLoginRequest?.state == request.state {
                    chzzkLoginRequest = nil
                }
            }
            do {
                let tokens = try await api.exchange(code: code, state: request.state)
                let user = try await api.user(accessToken: tokens.accessToken)
                guard chzzkLoginRequest?.state == request.state, request.streamId == stream.id else {
                    return
                }
                guard stream.chzzkChannelId.isEmpty || stream.chzzkChannelId == user.channelId else {
                    makeErrorToast(
                        title: String(localized: "The signed-in channel does not match this stream.")
                    )
                    return
                }
                chzzkRefreshTask?.cancel()
                chzzkRefreshTask = nil
                stream.chzzkChannelId = user.channelId
                chzzkAccount.channelId = user.channelId
                chzzkAccount.tokens = tokens
                chzzkAccount.store()
                storeSettings()
                chzzkChannelUpdated()
            } catch {
                if chzzkLoginRequest?.state == request.state, request.streamId == stream.id {
                    makeErrorToast(title: String(localized: "CHZZK login failed"))
                }
            }
        }
    }

    func chzzkSignOut() {
        let api = chzzkApi
        let refreshToken = chzzkAccount.tokens?.refreshToken
        cancelChzzkAuth()
        chzzkAccount.channelId = nil
        chzzkAccount.tokens = nil
        chzzkAccount.store()
        chzzkChannelUpdated()
        if let api, let refreshToken {
            Task {
                try? await api.revoke(refreshToken: refreshToken)
            }
        }
    }

    func chzzkAccessToken(forceRefresh: Bool = false) async throws -> String {
        guard chzzkLoggedIn, let tokens = chzzkAccount.tokens, let api = chzzkApi else {
            throw URLError(.userAuthenticationRequired)
        }
        if let chzzkRefreshTask {
            return try await chzzkRefreshTask.value
        }
        if !forceRefresh, tokens.expiresAt.timeIntervalSinceNow > 60 {
            return tokens.accessToken
        }
        let task = Task {
            defer {
                if !Task.isCancelled {
                    chzzkRefreshTask = nil
                }
            }
            let updated: ChzzkTokens
            do {
                updated = try await api.refresh(refreshToken: tokens.refreshToken)
            } catch let ChzzkApiError.status(status) where [400, 401, 403].contains(status) {
                try Task.checkCancellation()
                chzzkAccount.tokens = nil
                chzzkAccount.channelId = nil
                chzzkAccount.store()
                chzzkChannelUpdated()
                makeErrorToast(title: String(localized: "Log in to CHZZK again."))
                throw URLError(.userAuthenticationRequired)
            }
            try Task.checkCancellation()
            chzzkAccount.tokens = updated
            chzzkAccount.store()
            return updated.accessToken
        }
        chzzkRefreshTask = task
        return try await task.value
    }
}
