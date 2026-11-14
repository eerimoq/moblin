import SwiftUI
import WebKit

// Register an application in the VK Video Live developer cabinet (https://dev.live.vkvideo.ru)
// and enter its identifier here. The redirect URI below must be one of the redirect URIs
// entered when registering the application (must match exactly).
let vkVideoLiveMoblinAppClientId = "yy1v4boc46j4gln2"
private let vkVideoLiveDomain = "live.vkvideo.ru"
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
            VkVideoLiveAuthView(vkVideoLiveAuth: model.vkVideoLiveAuth)
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
        configuration.userContentController.addUserScript(WKUserScript(
            source: "try { localStorage.setItem('pwaHowToInstallModalDisplayed', '1') } catch (e) {}",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
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
        guard let url = webView.url, url.host() == redirectHost, let fragment = url.fragment(),
              let urlComponents = URLComponents(string: "foo:///?\(fragment)"),
              let token = urlComponents.queryItems?.first(where: { $0.name == "access_token" }),
              let accessToken = token.value
        else {
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

func removeUnusedVkVideoLiveAccessTokensInKeychain(usedStreamIds: [UUID]) {
    let usedStreamIds = Set(usedStreamIds.map(\.uuidString))
    for streamId in Keychain.loadStreamIds(server: vkVideoLiveDomain)
        where !usedStreamIds.contains(streamId)
    {
        createKeychain(streamId: streamId).remove()
    }
}

private func createKeychain(streamId: String) -> Keychain {
    Keychain(streamId: streamId, server: vkVideoLiveDomain, logPrefix: "vk-video-live: auth")
}
