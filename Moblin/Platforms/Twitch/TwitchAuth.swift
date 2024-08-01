import SwiftUI
import WebKit

private let authorizeUrl = "https://id.twitch.tv/oauth2/authorize"
let twitchMoblinAppClientId = "qv6bnocuwapqigeqjoamfhif0cv2xn"
private let scopes = [
    "user:read:chat",
]
private let redirectHost = "localhost"
private let redirectUri = "https://\(redirectHost)"

struct TwitchAuthView: UIViewRepresentable {
    @EnvironmentObject var model: Model

    func makeUIView(context _: Context) -> WKWebView {
        return model.twitchAuth.getWebBrowser()
    }

    func updateUIView(_: WKWebView, context _: Context) {}
}

class TwitchAuth: NSObject {
    private var webBrowser: WKWebView?
    private var onAccessToken: ((String) -> Void)?

    func getWebBrowser() -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = WKWebsiteDataStore.nonPersistent()
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
        guard let token = urlComponents.queryItems?.first(where: { item in
            item.name == "access_token"
        }) else {
            return
        }
        guard let accessToken = token.value else {
            return
        }
        onAccessToken?(accessToken)
    }
}
