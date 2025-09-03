import SwiftUI
import WebKit

private let kickDomain = "kick.com"
private let loginUrl = URL(string: "https://kick.com/login")!
private let sessionTokenCookieName = "session_token"

private struct AuthenticationView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var stream: SettingsStream
    @State private var showingWebView = false

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
            model.kickChannelNameUpdated()
        }
    }

    private func handleAccessToken(accessToken: String) {
        stream.kickAccessToken = accessToken
        stream.kickLoggedIn = true
        if stream.enabled {
            model.kickChannelNameUpdated()
        }
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

        init(_ onAccessToken: @escaping (String) -> Void) {
            self.onAccessToken = onAccessToken
        }

        func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
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
    }
}

private struct ChannelInfoView: View {
    let isLoading: Bool
    let channelId: String
    let channelName: String

    var body: some View {
        if isLoading {
            HStack {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Fetching channel info...")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        } else if !channelId.isEmpty {
            Text("Channel ID: \(channelId)")
                .foregroundColor(.secondary)
                .font(.caption)
        } else if !channelName.isEmpty {
            Text("Channel not found")
                .foregroundColor(.red)
                .font(.caption)
        }
    }
}

struct StreamKickSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var stream: SettingsStream
    @State var streamTitle: String = ""
    @State var isLoadingChannelInfo: Bool = false
    @State private var channelUpdateTimer: Timer?

    private let channelUpdateCooldown: TimeInterval = 2.5

    func submitChannelName(value: String) {
        stream.kickChannelName = value
        channelUpdateTimer?.invalidate()
        isLoadingChannelInfo = !value.isEmpty
        guard !value.isEmpty else {
            if stream.enabled {
                model.kickChannelNameUpdated()
            }
            return
        }
        channelUpdateTimer = Timer.scheduledTimer(withTimeInterval: channelUpdateCooldown, repeats: false) { _ in
            if stream.enabled {
                model.kickChannelNameUpdated()
            }
        }
    }

    func submitStreamTitle(value: String) {
        model.setKickStreamTitle(title: value) {
            streamTitle = $0
        }
    }

    var body: some View {
        Form {
            AuthenticationView(stream: stream)
            Section {
                TextEditNavigationView(
                    title: String(localized: "Channel name"),
                    value: stream.kickChannelName,
                    onSubmit: submitChannelName
                )
                ChannelInfoView(
                    isLoading: isLoadingChannelInfo,
                    channelId: stream.kickChatroomId,
                    channelName: stream.kickChannelName
                )
            }
            if stream.kickLoggedIn {
                Section {
                    TextEditBindingNavigationView(
                        title: String(localized: "Stream title"),
                        value: $streamTitle,
                        onSubmit: submitStreamTitle
                    )
                }
            }
        }
        .onAppear {
            if stream.kickLoggedIn && !stream.kickChannelName.isEmpty && streamTitle.isEmpty {
                model.getKickStreamTitle {
                    streamTitle = $0
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .kickChannelInfoUpdated)) { _ in
            isLoadingChannelInfo = false
        }
        .onDisappear {
            channelUpdateTimer?.invalidate()
        }
        .navigationTitle("Kick")
    }
}
