import SwiftUI
import WebKit

private let twitchServer = "www.twitch.tv"
private let authorizeUrl = "https://id.twitch.tv/oauth2/authorize"
let twitchMoblinAppClientId = "qv6bnocuwapqigeqjoamfhif0cv2xn"
private let scopes = [
    "user:read:chat",
    "moderator:read:followers",
    "channel:read:subscriptions",
    "channel:read:stream_key",
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

private func updateAccessTokenInKeychain(streamId: String, accessTokenData: Data) -> Bool {
    let query: [String: Any] = [
        kSecClass as String: kSecClassInternetPassword,
        kSecAttrServer as String: twitchServer,
        kSecAttrAccount as String: streamId,
    ]
    let attributes: [String: Any] = [
        kSecAttrAccount as String: streamId,
        kSecValueData as String: accessTokenData,
    ]
    let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
    guard status != errSecItemNotFound else {
        return false
    }
    guard status == errSecSuccess else {
        logger.info("twitch: auth: Failed to update item in keychain")
        return false
    }
    return true
}

private func addAccessTokenInKeychain(streamId: String, accessTokenData: Data) {
    let attributes: [String: Any] = [
        kSecClass as String: kSecClassInternetPassword,
        kSecAttrServer as String: twitchServer,
        kSecAttrAccount as String: streamId,
        kSecValueData as String: accessTokenData,
    ]
    let status = SecItemAdd(attributes as CFDictionary, nil)
    guard status == errSecSuccess else {
        logger.info("twitch: auth: Failed to add item to keychain")
        return
    }
}

func storeTwitchAccessTokenInKeychain(streamId: UUID, accessToken: String) {
    guard let accessTokenData = accessToken.data(using: .utf8) else {
        return
    }
    let streamId = streamId.uuidString
    if !updateAccessTokenInKeychain(streamId: streamId, accessTokenData: accessTokenData) {
        addAccessTokenInKeychain(streamId: streamId, accessTokenData: accessTokenData)
    }
}

func loadTwitchAccessTokenFromKeychain(streamId: UUID) -> String? {
    let query: [String: Any] = [
        kSecClass as String: kSecClassInternetPassword,
        kSecAttrServer as String: twitchServer,
        kSecAttrAccount as String: streamId.uuidString,
        kSecMatchLimit as String: kSecMatchLimitOne,
        kSecReturnAttributes as String: true,
        kSecReturnData as String: true,
    ]
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    guard status != errSecItemNotFound else {
        return nil
    }
    guard status == errSecSuccess else {
        logger.info("twitch: auth: Failed to query item to keychain")
        return nil
    }
    guard let existingItem = item as? [String: Any],
          let accessTokenData = existingItem[kSecValueData as String] as? Data,
          let accessToken = String(data: accessTokenData, encoding: String.Encoding.utf8)
    else {
        logger.info("twitch: auth: Failed to lookup attributes")
        return nil
    }
    return accessToken
}

func removeTwitchAccessTokenInKeychain(streamId: UUID) {
    let query: [String: Any] = [
        kSecClass as String: kSecClassInternetPassword,
        kSecAttrServer as String: twitchServer,
        kSecAttrAccount as String: streamId.uuidString,
    ]
    let status = SecItemDelete(query as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
        logger.info("twitch: auth: Keychain delete failed")
        return
    }
}
