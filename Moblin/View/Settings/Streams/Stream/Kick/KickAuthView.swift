import SwiftUI
import WebKit

// Global WebView instance to persist across app lifecycle
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
                    }) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "person.crop.circle.badge.plus")
                            }
                            Text("Log in to Kick")
                        }
                    }
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
                    // Minimal toolbar
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

        // Find session_token cookie
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
        // Clear website data first
        WKWebsiteDataStore.default().removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: Date(timeIntervalSince1970: 0)
        ) {
            DispatchQueue.main.async {
                // Clear and reload the persistent WebView
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
        // Use persistent WebView if it exists, otherwise create new one
        if let existingWebView = persistentWebView {
            existingWebView.navigationDelegate = context.coordinator
            return existingWebView
        }

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()

        // Enable better scrolling and keyboard handling
        configuration.preferences.javaScriptEnabled = true

        // Configure for persistence
        configuration.suppressesIncrementalRendering = false
        configuration.allowsInlineMediaPlayback = true
        configuration.processPool = WKProcessPool() // Shared process pool

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator

        // Configure essential scroll view settings for login
        webView.scrollView.keyboardDismissMode = .onDrag
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic

        // Configure WebView settings
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = false

        // Store globally for persistence
        persistentWebView = webView

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Update the delegate in case it changed
        webView.navigationDelegate = context.coordinator

        // Load login page if needed
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

            // Only extract token if we're on a logged-in page (not login/register page)
            if !url.contains("/login"), !url.contains("/register"), url.contains(KickAuthConstants.kickDomain) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.extractAuthToken(from: webView)
                }
            }
        }

        private func extractAuthToken(from _: WKWebView) {
            // Get session cookies
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
