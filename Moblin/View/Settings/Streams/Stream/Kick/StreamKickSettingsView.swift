import SwiftUI
import WebKit

private var persistentWebView: WKWebView?
private let loginUrl = URL(string: "https://kick.com/login")!
private let sessionTokenCookieName = "session_token"
private let kickDomain = "kick.com"

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
                        Button("Close") {
                            showingWebView = false
                        }
                    }
                    .padding()
                    KickWebView {
                        handleAccessToken(accessToken: $0)
                    }
                }
                .ignoresSafeArea(.keyboard)
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

    private func handleAccessToken(accessToken: String) {
        stream.kickAccessToken = accessToken
        stream.kickLoggedIn = true
        showingWebView = false
        if stream.enabled {
            model.kickChannelNameUpdated()
        }
    }
}

private struct KickWebView: UIViewRepresentable {
    let onTokenExtracted: (String) -> Void

    func makeUIView(context: Context) -> WKWebView {
        if let existingWebView = persistentWebView {
            existingWebView.navigationDelegate = context.coordinator
            return existingWebView
        }
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
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
        return !url.contains(kickDomain)
    }

    private func loadLoginPage(webView: WKWebView) {
        var request = URLRequest(url: loginUrl)
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
            if !url.contains("/login"), !url.contains("/register"), url.contains(kickDomain) {
                extractAuthToken(from: webView)
            }
        }

        private func extractAuthToken(from webView: WKWebView) {
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    guard let sessionTokenCookie = cookies
                        .filter({ $0.domain.contains(kickDomain) })
                        .filter({ $0.name == sessionTokenCookieName })
                        .first
                    else {
                        return
                    }
                    let accessToken = sessionTokenCookie.value.removingPercentEncoding ?? sessionTokenCookie.value
                    self.parent.onTokenExtracted(accessToken)
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
