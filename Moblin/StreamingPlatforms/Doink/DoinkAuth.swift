import AuthenticationServices
import SwiftUI
import WebKit

private let authorizeUrl = "https://doink.tv/oauth/authorize"
private let doinkMoblinAppClientId = "moblin"
private let browserRedirectHost = "localhost"
private let browserRedirectUri = "https://\(browserRedirectHost)"
private let sessionRedirectHost = "mys-lang.org"
private let sessionRedirectPath = "/auth"
private let sessionRedirectUri = "https://\(sessionRedirectHost)\(sessionRedirectPath)"
private let doinkAuthServer = "doink.tv"

private struct DoinkAuthView: UIViewRepresentable {
    let doinkAuth: DoinkAuth

    func makeUIView(context _: Context) -> WKWebView {
        doinkAuth.getWebBrowser()
    }

    func updateUIView(_: WKWebView, context _: Context) {}
}

struct DoinkLoginView: View {
    let model: Model
    @Binding var presenting: Bool

    var body: some View {
        ZStack {
            ScrollView {
                DoinkAuthView(doinkAuth: model.doinkAuth)
                    .frame(height: 2500)
            }
            CloseButtonTopRightView {
                presenting = false
            }
        }
    }
}

@MainActor
class DoinkAuth: NSObject {
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
        guard #available(iOS 17.4, *), let url = buildAuthUrl(redirectUri: sessionRedirectUri) else {
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
            logger.info("doink: auth: Session failed with \(error)")
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
            .init(name: "client_id", value: doinkMoblinAppClientId),
            .init(name: "redirect_uri", value: redirectUri),
            .init(name: "response_type", value: "token"),
            .init(name: "state", value: randomHumanString()),
        ]
        return urlComponents.url
    }
}

extension DoinkAuth: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for _: ASWebAuthenticationSession) -> ASPresentationAnchor {
        getWindow() ?? ASPresentationAnchor()
    }
}

extension DoinkAuth: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
        guard let url = webView.url, url.host() == browserRedirectHost,
              let accessToken = extractAccessToken(url: url)
        else {
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
    guard let fragment = url.fragment(),
          let urlComponents = URLComponents(string: "foo:///?\(fragment)")
    else {
        return nil
    }
    return urlComponents.queryItems?.first(where: { $0.name == "access_token" })?.value
}

func storeDoinkAccessTokenInKeychain(streamId: UUID, accessToken: String) {
    createKeychain(streamId: streamId.uuidString).store(value: accessToken)
}

func loadDoinkAccessTokenFromKeychain(streamId: UUID) -> String? {
    createKeychain(streamId: streamId.uuidString).load()
}

func removeDoinkAccessTokenInKeychain(streamId: UUID) {
    createKeychain(streamId: streamId.uuidString).remove()
}

func removeUnusedDoinkAccessTokensInKeychain(usedStreamIds: [UUID]) {
    let usedStreamIds = Set(usedStreamIds.map(\.uuidString))
    for streamId in Keychain.loadStreamIds(server: doinkAuthServer) where !usedStreamIds.contains(streamId) {
        createKeychain(streamId: streamId).remove()
    }
}

private func createKeychain(streamId: String) -> Keychain {
    Keychain(streamId: streamId, server: doinkAuthServer, logPrefix: "doink: auth")
}
