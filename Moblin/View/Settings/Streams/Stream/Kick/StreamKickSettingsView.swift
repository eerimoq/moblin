import SwiftUI
import WebKit

private let kickDomain = "kick.com"
private let loginUrl = URL(string: "https://kick.com/login")!
private let sessionTokenCookieName = "session_token"

private struct AuthenticationView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var stream: SettingsStream
    @State private var showingWebView = false
    let onLoggedIn: () -> Void

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
                    logout()
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
                        showingWebView = false
                    }
                }
                .ignoresSafeArea(.keyboard)
            }
        }
    }

    private func logout() {
        stream.kickAccessToken = ""
        stream.kickLoggedIn = false
        if stream.enabled {
            model.kickAccessTokenUpdated()
        }
    }

    private func handleAccessToken(accessToken: String) {
        stream.kickAccessToken = accessToken
        stream.kickLoggedIn = true
        onLoggedIn()
    }
}

private struct KickWebView: UIViewRepresentable {
    let onAccessToken: (String) -> Void

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.navigationDelegate = context.coordinator
        if webView.url?.host()?.contains(kickDomain) != true {
            webView.load(URLRequest(url: loginUrl))
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onAccessToken)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let onAccessToken: (String) -> Void
        private var loginButtonClicked = false

        init(_ onAccessToken: @escaping (String) -> Void) {
            self.onAccessToken = onAccessToken
        }

        func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
            if !loginButtonClicked {
                detectAndClickLoginButton(webView)
            }
            guard let url = webView.url,
                  let host = url.host(),
                  !url.path().contains("/login"),
                  !url.path().contains("/register"),
                  host.contains(kickDomain)
            else {
                return
            }
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                guard let sessionTokenCookie = cookies
                    .filter({ $0.domain.contains(kickDomain) })
                    .filter({ $0.name == sessionTokenCookieName })
                    .first
                else {
                    return
                }
                let accessToken = sessionTokenCookie.value
                DispatchQueue.main.async {
                    self.onAccessToken(accessToken.removingPercentEncoding ?? accessToken)
                }
            }
        }

        private func detectAndClickLoginButton(_ webView: WKWebView) {
            let detectAndClickLoginButtonScript = """
            (async function() {
                try {
                    // wait for 0.2 second for the page to load
                    await new Promise(resolve => setTimeout(resolve, 200));
                    var loginButton = document.querySelector('[data-testid="login"]');
                    if (loginButton) {
                        loginButton.click();
                        return true;
                    }
                } catch (error) {
                    return false;
                }
            })();
            """
            webView.evaluateJavaScript(detectAndClickLoginButtonScript) { result, error in
                if error != nil {
                    return
                }
                if result as? Bool == true {
                    self.loginButtonClicked = true
                }
            }
        }
    }
}

struct KickAlertsSettingsView: View {
    let title: String
    @ObservedObject var alerts: SettingsKickAlerts

    var body: some View {
        Form {
            Section {
                Toggle("Subscriptions", isOn: $alerts.subscriptions)
                Toggle("Gift subscriptions", isOn: $alerts.giftedSubscriptions)
                Toggle("Rewards", isOn: $alerts.rewards)
                Toggle("Hosts", isOn: $alerts.hosts)
                Toggle("Bans and timeouts", isOn: $alerts.bans)
                Toggle("Kicks", isOn: $alerts.kicks)
                TextEditNavigationView(
                    title: String(localized: "Minimum kicks"),
                    value: String(alerts.minimumKicks),
                    onSubmit: {
                        alerts.minimumKicks = Int($0) ?? 0
                    }
                )
            }
        }
        .navigationTitle(title)
    }
}

struct StreamKickSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var stream: SettingsStream
    @State var streamTitle: String = ""
    @State var fetchChannelInfoFailed: Bool = false

    private func shouldFetchChannelInfo() -> Bool {
        return !stream.kickChannelName.isEmpty
            && (stream.kickChannelId == nil || stream.kickSlug == nil || stream.kickChatroomChannelId == nil)
    }

    private func fetchChannelInfo() {
        fetchChannelInfoFailed = false
        getKickChannelInfo(channelName: stream.kickChannelName) { channelInfo in
            DispatchQueue.main.async {
                if let channelInfo {
                    self.stream.kickChannelId = String(channelInfo.chatroom.id)
                    self.stream.kickSlug = channelInfo.slug
                    self.stream.kickChatroomChannelId = String(channelInfo.chatroom.channel_id)
                } else {
                    fetchChannelInfoFailed = true
                }
                reloadConnectionsIfEnabled()
            }
        }
    }

    private func submitChannelName(value: String) {
        stream.kickChannelName = value
        stream.kickChannelId = nil
        stream.kickSlug = nil
        if stream.enabled, stream.kickChannelName.isEmpty {
            model.kickChannelNameUpdated()
        }
    }

    private func submitStreamTitle(value: String) {
        model.setKickStreamTitle(title: value) {
            streamTitle = $0
        }
    }

    private func onLoggedIn() {
        getKickUser(accessToken: stream.kickAccessToken) { data in
            DispatchQueue.main.async {
                self.handleUser(data: data)
            }
        }
    }

    private func handleUser(data: KickUser?) {
        if let data {
            stream.kickChannelName = data.username
            stream.kickChannelId = nil
            stream.kickSlug = nil
            fetchChannelInfo()
        } else {
            reloadConnectionsIfEnabled()
        }
    }

    private func reloadConnectionsIfEnabled() {
        if stream.enabled {
            model.kickAccessTokenUpdated()
        }
    }

    var body: some View {
        Form {
            AuthenticationView(stream: stream, onLoggedIn: onLoggedIn)
            Section {
                TextEditNavigationView(
                    title: String(localized: "Channel name"),
                    value: stream.kickChannelName,
                    onChange: { _ in nil },
                    onSubmit: submitChannelName
                )
                .id(stream.kickChannelName)
            } footer: {
                if fetchChannelInfoFailed {
                    Text("Channel not found on kick.com.")
                        .foregroundColor(.red)
                } else if shouldFetchChannelInfo() {
                    Text("Fetching channel info...")
                }
            }
            if stream.kickLoggedIn {
                Section {
                    TextEditNavigationView(
                        title: String(localized: "Stream title"),
                        value: streamTitle,
                        onSubmit: submitStreamTitle
                    )
                }
            }
            Section {
                NavigationLink {
                    KickAlertsSettingsView(title: String(localized: "Chat"), alerts: stream.kickChatAlerts)
                } label: {
                    Text("Chat")
                }
                NavigationLink {
                    KickAlertsSettingsView(title: String(localized: "Toasts"), alerts: stream.kickToastAlerts)
                } label: {
                    Text("Toasts")
                }
            } header: {
                Text("Alerts")
            }
        }
        .onAppear {
            if stream.kickLoggedIn && !stream.kickChannelName.isEmpty && streamTitle.isEmpty {
                model.getKickStreamTitle {
                    streamTitle = $0
                }
            }
            if shouldFetchChannelInfo() {
                fetchChannelInfo()
            }
        }
        .navigationTitle("Kick")
    }
}
