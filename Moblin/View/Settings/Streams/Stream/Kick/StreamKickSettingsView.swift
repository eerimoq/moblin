import SwiftUI
import WebKit

private var persistentWebView: WKWebView?

private enum KickAuthConstants {
    static let loginURL = "https://kick.com/login"
    static let sessionTokenCookieName = "session_token"
    static let kickDomain = "kick.com"
    static let tokenExtractionDelay: TimeInterval = 2.0
}

struct KickAuthView: View {
    @EnvironmentObject var model: Model
    @State private var showingWebView = false
    @ObservedObject var stream: SettingsStream

    var body: some View {
        Section {
            if !stream.kickLoggedIn {
                Button {
                    showingWebView = true
                } label: {
                    HCenter {
                        Text("Login")
                    }
                }
            } else {
                Button {
                    logOut()
                } label: {
                    HCenter {
                        Text("Logout")
                    }
                }
            }
        }
        .sheet(isPresented: $showingWebView) {
            NavigationView {
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        Button("Clear session") {
                            clearWebViewSession()
                        }
                        Button("Close") {
                            showingWebView = false
                        }
                    }
                    .padding()
                    KickWebView { sessionCookies in
                        handleTokenExtracted(cookies: sessionCookies)
                    }
                }
                .ignoresSafeArea(.keyboard)
            }
        }
    }

    private func handleTokenExtracted(cookies: [HTTPCookie]) {
        if let sessionTokenCookie = cookies.first(where: { $0.name == KickAuthConstants.sessionTokenCookieName }) {
            let decodedToken = sessionTokenCookie.value.removingPercentEncoding ?? sessionTokenCookie.value
            DispatchQueue.main.async {
                stream.kickAccessToken = decodedToken
                stream.kickLoggedIn = true
                showingWebView = false
                if stream.enabled {
                    model.kickChannelNameUpdated()
                }
            }
        } else {
            DispatchQueue.main.async {
                model.makeErrorToast(title: "Login failed", subTitle: "Could not extract authentication token")
            }
        }
    }

    private func logOut() {
        stream.kickAccessToken = ""
        stream.kickLoggedIn = false
        if stream.enabled {
            model.kickChannelNameUpdated()
        }
    }

    private func clearWebViewSession() {
        WKWebsiteDataStore.default().removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: Date(timeIntervalSince1970: 0)
        ) {
            DispatchQueue.main.async {
                if let webView = persistentWebView {
                    let loginURL = URL(string: KickAuthConstants.loginURL)!
                    let request = URLRequest(url: loginURL)
                    webView.load(request)
                }
                persistentWebView = nil
            }
        }
    }
}

private struct KickWebView: UIViewRepresentable {
    let onTokenExtracted: ([HTTPCookie]) -> Void

    func makeUIView(context: Context) -> WKWebView {
        if let existingWebView = persistentWebView {
            existingWebView.navigationDelegate = context.coordinator
            return existingWebView
        }
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.suppressesIncrementalRendering = false
        configuration.allowsInlineMediaPlayback = true
        configuration.processPool = WKProcessPool()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.keyboardDismissMode = .onDrag
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = false
        persistentWebView = webView
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.navigationDelegate = context.coordinator
        if shouldLoadLoginPage(webView: webView) {
            loadLoginPage(webView: webView)
        }
    }

    private func shouldLoadLoginPage(webView: WKWebView) -> Bool {
        guard let url = webView.url?.absoluteString else { return true }
        return !url.contains(KickAuthConstants.kickDomain)
    }

    private func loadLoginPage(webView: WKWebView) {
        guard let loginURL = URL(string: KickAuthConstants.loginURL) else {
            print("Failed to create login URL")
            return
        }
        var request = URLRequest(url: loginURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15",
                         forHTTPHeaderField: "User-Agent")
        webView.load(request)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: KickWebView
        init(_ parent: KickWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
            guard let url = webView.url?.absoluteString else { return }
            if !url.contains("/login"), !url.contains("/register"), url.contains(KickAuthConstants.kickDomain) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.extractAuthToken(from: webView)
                }
            }
        }

        private func extractAuthToken(from _: WKWebView) {
            WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
                let kickCookies = cookies.filter { $0.domain.contains(KickAuthConstants.kickDomain) }
                DispatchQueue.main.async {
                    if kickCookies.contains(where: { $0.name == KickAuthConstants.sessionTokenCookieName }) {
                        self.parent.onTokenExtracted(kickCookies)
                    }
                }
            }
        }
    }
}

struct StreamKickSettingsView: View {
    @EnvironmentObject var model: Model
    let stream: SettingsStream

    func submitChannelName(value: String) {
        stream.kickChannelName = value
        if stream.enabled {
            model.kickChannelNameUpdated()
        }
    }

    var body: some View {
        Form {
            if model.database.debug.kickLogin {
                KickAuthView(stream: stream)
            }
            Section {
                TextEditNavigationView(
                    title: String(localized: "Channel name"),
                    value: stream.kickChannelName,
                    onSubmit: submitChannelName
                )
            }
        }
        .navigationTitle("Kick")
    }
}
