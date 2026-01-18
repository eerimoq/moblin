import SwiftUI
import WebKit

private let authorizeUrl = "https://id.twitch.tv/oauth2/authorize"
let twitchMoblinAppClientId = "qv6bnocuwapqigeqjoamfhif0cv2xn"
private let scopes = [
    "user:read:chat",
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
    "channel:moderate",
    "channel:read:subscriptions",
    "channel:read:redemptions",
    "channel:read:stream_key",
    "channel:read:hype_train",
    "channel:read:ads",
    "channel:manage:broadcast",
    "channel:manage:moderators",
    "channel:manage:vips",
    "channel:manage:raids",
    "channel:edit:commercial",
    "bits:read",
]
private let redirectHost = "localhost"
private let redirectUri = "https://\(redirectHost)"

private struct TwitchAuthView: UIViewRepresentable {
    let twitchAuth: TwitchAuth

    func makeUIView(context _: Context) -> WKWebView {
        return twitchAuth.getWebBrowser()
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

class TwitchAuth: NSObject {
    private var webBrowser: WKWebView?
    private var onAccessToken: ((String) -> Void)?

    func getWebBrowser() -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        webBrowser = WKWebView(frame: .zero, configuration: configuration)
        webBrowser!.navigationDelegate = self
        webBrowser!.load(URLRequest(url: buildAuthUrl()!))
        return webBrowser!
    }

    func setOnAccessToken(onAccessToken: @escaping ((String) -> Void)) {
        self.onAccessToken = onAccessToken
    }

    private func buildAuthUrl() -> URL? {
        guard var urlComponents = URLComponents(string: authorizeUrl) else {
            return nil
        }
        urlComponents.queryItems = [
            .init(name: "client_id", value: twitchMoblinAppClientId),
            .init(name: "redirect_uri", value: redirectUri),
            .init(name: "response_type", value: "token"),
            .init(name: "scope", value: scopes.joined(separator: "+")),
        ]
        return urlComponents.url
    }
}

extension TwitchAuth: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
        guard let url = webView.url else {
            return
        }
        guard url.host() == redirectHost else {
            return
        }
        guard let fragment = url.fragment() else {
            return
        }
        guard let urlComponents = URLComponents(string: "foo:///?\(fragment)") else {
            return
        }
        guard let token = urlComponents.queryItems?.first(where: { $0.name == "access_token" }) else {
            return
        }
        guard let accessToken = token.value else {
            return
        }
        onAccessToken?(accessToken)
    }
}

func storeTwitchAccessTokenInKeychain(streamId: UUID, accessToken: String) {
    createKeychain(streamId: streamId.uuidString).store(value: accessToken)
}

func loadTwitchAccessTokenFromKeychain(streamId: UUID) -> String? {
    return createKeychain(streamId: streamId.uuidString).load()
}

func removeTwitchAccessTokenInKeychain(streamId: UUID) {
    createKeychain(streamId: streamId.uuidString).remove()
}

private func createKeychain(streamId: String) -> Keychain {
    return Keychain(streamId: streamId, server: "www.twitch.tv", logPrefix: "twitch: auth")
}
