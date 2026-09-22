import AuthenticationServices
import SwiftUI
import WebKit

private let authorizeUrl = "https://id.twitch.tv/oauth2/authorize"
let twitchMoblinAppClientId = "qv6bnocuwapqigeqjoamfhif0cv2xn"
private let scopes = [
    "user:read:chat",
    "user:read:follows",
    "user:write:chat",
    "moderator:read:followers",
    "moderator:read:blocked_terms",
    "moderator:read:unban_requests",
    "moderator:read:warnings",
    "moderator:read:moderators",
    "moderator:read:vips",
    "moderator:manage:chat_messages",
    "moderator:manage:banned_users",
    "moderator:manage:chat_settings",
    "moderator:manage:announcements",
    "moderator:manage:shoutouts",
    "channel:moderate",
    "channel:read:subscriptions",
    "channel:read:redemptions",
    "channel:read:stream_key",
    "channel:read:hype_train",
    "channel:read:ads",
    "channel:manage:polls",
    "channel:manage:predictions",
    "channel:manage:broadcast",
    "channel:manage:moderators",
    "channel:manage:vips",
    "channel:manage:raids",
    "channel:edit:commercial",
    "bits:read",
]
private let browserRedirectHost = "localhost"
private let browserRedirectUri = "https://\(browserRedirectHost)"
private let sessionRedirectHost = "mys-lang.org"
private let sessionRedirectPath = "/auth"
private let sessionRedirectUri = "https://\(sessionRedirectHost)\(sessionRedirectPath)"
private let twitchAuthServer = "www.twitch.tv"

private struct TwitchAuthView: UIViewRepresentable {
    let twitchAuth: TwitchAuth

    func makeUIView(context _: Context) -> WKWebView {
        twitchAuth.getWebBrowser()
    }

    func updateUIView(_: WKWebView, context _: Context) {}
}

struct TwitchLoginView: View {
    let model: Model
    @Binding var presenting: Bool

    var body: some View {
        ZStack {
            ScrollView {
                TwitchAuthView(twitchAuth: model.twitchAuth)
                    .frame(height: 2500)
            }
            CloseButtonTopRightView {
                presenting = false
            }
        }
    }
}

@MainActor
class TwitchAuth: NSObject {
    private var webBrowser: WKWebView?
    private var session: ASWebAuthenticationSession?
    private var onAccessToken: ((String) -> Void)?
    private var showWebBrowser: (() -> Void)?

    func login(showWebBrowser: @escaping () -> Void) {
        self.showWebBrowser = showWebBrowser
        if !startSession() {
            showWebBrowser()
        }
    }

    private func startSession() -> Bool {
        guard #available(iOS 17.4, *) else {
            return false
        }
        guard let url = buildAuthUrl(redirectUri: sessionRedirectUri) else {
            return false
        }
        let session = ASWebAuthenticationSession(
            url: url,
            callback: .https(host: sessionRedirectHost, path: sessionRedirectPath)
        ) { @Sendable url, error in
            DispatchQueue.main.async {
                self.handleSessionCompleted(url: url, error: error)
            }
        }
        session.presentationContextProvider = self
        self.session = session
        return session.start()
    }

    private func handleSessionCompleted(url: URL?, error: Error?) {
        session = nil
        if let error {
            logger.info("twitch: auth: Session failed with \(error)")
            if !isCanceledByUser(error: error) {
                showWebBrowser?()
            }
            return
        }
        guard let url, let accessToken = extractAccessToken(url: url) else {
            return
        }
        onAccessToken?(accessToken)
    }

    func getWebBrowser() -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        webBrowser = WKWebView(frame: .zero, configuration: configuration)
        webBrowser!.navigationDelegate = self
        webBrowser!.load(URLRequest(url: buildAuthUrl(redirectUri: browserRedirectUri)!))
        return webBrowser!
    }

    func setOnAccessToken(onAccessToken: @escaping ((String) -> Void)) {
        self.onAccessToken = onAccessToken
    }

    private func buildAuthUrl(redirectUri: String) -> URL? {
        guard var urlComponents = URLComponents(string: authorizeUrl) else {
            return nil
        }
        urlComponents.queryItems = [
            .init(name: "client_id", value: twitchMoblinAppClientId),
            .init(name: "force_verify", value: "true"),
            .init(name: "redirect_uri", value: redirectUri),
            .init(name: "response_type", value: "token"),
            .init(name: "scope", value: scopes.joined(separator: "+")),
            .init(name: "state", value: randomHumanString()),
        ]
        return urlComponents.url
    }
}

extension TwitchAuth: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for _: ASWebAuthenticationSession) -> ASPresentationAnchor {
        getWindow() ?? ASPresentationAnchor()
    }
}

extension TwitchAuth: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
        guard let url = webView.url else {
            return
        }
        guard url.host() == browserRedirectHost else {
            return
        }
        guard let accessToken = extractAccessToken(url: url) else {
            return
        }
        onAccessToken?(accessToken)
    }
}

private func isCanceledByUser(error: Error) -> Bool {
    let error = error as NSError
    guard error.domain == ASWebAuthenticationSessionErrorDomain,
          error.code == ASWebAuthenticationSessionError.canceledLogin.rawValue
    else {
        return false
    }
    return error.userInfo[NSLocalizedFailureReasonErrorKey] == nil
}

private func extractAccessToken(url: URL) -> String? {
    guard let fragment = url.fragment() else {
        return nil
    }
    guard let urlComponents = URLComponents(string: "foo:///?\(fragment)") else {
        return nil
    }
    return urlComponents.queryItems?.first(where: { $0.name == "access_token" })?.value
}

func storeTwitchAccessTokenInKeychain(streamId: UUID, accessToken: String) {
    createKeychain(streamId: streamId.uuidString).store(value: accessToken)
}

func loadTwitchAccessTokenFromKeychain(streamId: UUID) -> String? {
    createKeychain(streamId: streamId.uuidString).load()
}

func removeTwitchAccessTokenInKeychain(streamId: UUID) {
    createKeychain(streamId: streamId.uuidString).remove()
}

func removeUnusedTwitchAccessTokensInKeychain(usedStreamIds: [UUID]) {
    let usedStreamIds = Set(usedStreamIds.map(\.uuidString))
    for streamId in Keychain.loadStreamIds(server: twitchAuthServer) where !usedStreamIds.contains(streamId) {
        createKeychain(streamId: streamId).remove()
    }
}

private func createKeychain(streamId: String) -> Keychain {
    Keychain(streamId: streamId, server: twitchAuthServer, logPrefix: "twitch: auth")
}
