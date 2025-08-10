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
    @State private var isLoading = false
    let stream: SettingsStream
    var body: some View {
        Form {
            Section {
                if stream.kickLoggedIn {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Logged in to Kick")
                        Spacer()
                        Button("Log Out") {
                            logOut()
                        }
                        .foregroundColor(.red)
                    }
                } else {
                    Button(action: {
                        showingWebView = true
                    }, label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "person.crop.circle.badge.plus")
                            }
                            Text("Log in to Kick")
                        }
                    })
                    .disabled(isLoading)
                }
            } header: {
                Text("Authentication")
            } footer: {
                Text("Log in to Kick.com to send chat messages")
            }
        }
        .navigationTitle("Kick Authentication")
        .sheet(isPresented: $showingWebView) {
            NavigationView {
                VStack(spacing: 0) {
                    HStack {
                        Button("Cancel") {
                            showingWebView = false
                        }
                        Spacer()
                        Button("Clear Session") {
                            clearWebViewSession()
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    KickWebView(
                        onTokenExtracted: { token, sessionCookies in
                            handleTokenExtracted(token: token, cookies: sessionCookies)
                        }
                    )
                }
                .ignoresSafeArea(.keyboard)
            }
            .presentationDetents([.large])
        }
    }
    private func handleTokenExtracted(token _: String?, cookies: [HTTPCookie]) {
        isLoading = true
        if let sessionTokenCookie = cookies.first(where: { $0.name == KickAuthConstants.sessionTokenCookieName }) {
            let decodedToken = sessionTokenCookie.value.removingPercentEncoding ?? sessionTokenCookie.value
            DispatchQueue.main.async {
                stream.kickAccessToken = decodedToken
                stream.kickLoggedIn = true
                showingWebView = false
                isLoading = false
                model.makeToast(title: "Successfully logged in to Kick")
                if stream.enabled {
                    model.kickChannelNameUpdated()
                }
            }
        } else {
            DispatchQueue.main.async {
                isLoading = false
                model.makeErrorToast(title: "Login failed", subTitle: "Could not extract authentication token")
            }
        }
    }
    private func logOut() {
        stream.kickAccessToken = ""
        stream.kickLoggedIn = false
        model.makeToast(title: "Logged out from Kick")
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
                self.model.makeToast(title: "WebView session cleared")
            }
        }
    }
}
struct KickWebView: UIViewRepresentable {
    let onTokenExtracted: (String?, [HTTPCookie]) -> Void
    func makeUIView(context: Context) -> WKWebView {
        if let existingWebView = persistentWebView {
            existingWebView.navigationDelegate = context.coordinator
            return existingWebView
        }
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.preferences.javaScriptEnabled = true
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
                        self.parent.onTokenExtracted(nil, kickCookies)
                    }
                }
            }
        }
    }
}
