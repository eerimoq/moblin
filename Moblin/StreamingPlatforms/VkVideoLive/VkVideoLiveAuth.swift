import SwiftUI
import WebKit

// Register an application in the VK Video Live developer cabinet (https://dev.live.vkvideo.ru)
// and enter its identifier here. The redirect URI below must be one of the redirect URIs
// entered when registering the application (must match exactly).
let vkVideoLiveMoblinAppClientId = "yy1v4boc46j4gln2"
private let redirectHost = "localhost"
private let redirectUri = "https://\(redirectHost)"
private let authorizeUrl = "https://auth.live.vkvideo.ru/app/oauth2/authorize"
private let scopes = [
    "chat:message:send",
    "chat:settings",
    "channel:stream:settings",
]

private struct VkVideoLiveAuthView: UIViewRepresentable {
    let vkVideoLiveAuth: VkVideoLiveAuth

    func makeUIView(context _: Context) -> WKWebView {
        vkVideoLiveAuth.getWebBrowser()
    }

    func updateUIView(_: WKWebView, context _: Context) {}
}

struct VkVideoLiveLoginView: View {
    let model: Model
    @Binding var presenting: Bool

    var body: some View {
        ZStack {
            ScrollView {
                VkVideoLiveAuthView(vkVideoLiveAuth: model.vkVideoLiveAuth)
                    .frame(height: 2500)
            }
            CloseButtonTopRightView {
                presenting = false
            }
        }
    }
}

@MainActor
class VkVideoLiveAuth: NSObject {
    private var webBrowser: WKWebView?
    private var popupWebBrowser: WKWebView?
    private var onAccessToken: ((String) -> Void)?

    func getWebBrowser() -> WKWebView {
        closePopup()
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        webBrowser = WKWebView(frame: .zero, configuration: configuration)
        webBrowser!.navigationDelegate = self
        webBrowser!.uiDelegate = self
        if let url = buildAuthUrl() {
            webBrowser!.load(URLRequest(url: url))
        }
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
            .init(name: "client_id", value: vkVideoLiveMoblinAppClientId),
            .init(name: "redirect_uri", value: redirectUri),
            .init(name: "response_type", value: "token"),
            .init(name: "scope", value: scopes.joined(separator: ",")),
            .init(name: "state", value: randomHumanString()),
        ]
        return urlComponents.url
    }

    private func closePopup() {
        popupWebBrowser?.removeFromSuperview()
        popupWebBrowser = nil
    }
}

extension VkVideoLiveAuth: WKUIDelegate {
    // The VK ID login form opens in a popup window. Show it on top of the
    // authorization page, keeping the opener relationship so that the form can
    // communicate its result back to the page.
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for _: WKNavigationAction,
                 windowFeatures _: WKWindowFeatures) -> WKWebView?
    {
        closePopup()
        let popup = WKWebView(frame: webView.bounds, configuration: configuration)
        popup.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        popup.navigationDelegate = self
        popup.uiDelegate = self
        webView.addSubview(popup)
        popupWebBrowser = popup
        return popup
    }

    func webViewDidClose(_ webView: WKWebView) {
        if webView == popupWebBrowser {
            closePopup()
        }
    }
}

extension VkVideoLiveAuth: WKNavigationDelegate {
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

func storeVkVideoLiveAccessTokenInKeychain(streamId: UUID, accessToken: String) {
    createKeychain(streamId: streamId.uuidString).store(value: accessToken)
}

func loadVkVideoLiveAccessTokenFromKeychain(streamId: UUID) -> String? {
    createKeychain(streamId: streamId.uuidString).load()
}

func removeVkVideoLiveAccessTokenInKeychain(streamId: UUID) {
    createKeychain(streamId: streamId.uuidString).remove()
}

private func createKeychain(streamId: String) -> Keychain {
    Keychain(streamId: streamId, server: "live.vkvideo.ru", logPrefix: "vk-video-live: auth")
}
