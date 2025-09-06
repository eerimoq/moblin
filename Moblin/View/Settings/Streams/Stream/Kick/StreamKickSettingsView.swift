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
            model.kickAccessTokenUpdated()
        }
    }

    private func handleAccessToken(accessToken: String) {
        stream.kickAccessToken = accessToken
        stream.kickLoggedIn = true
        if stream.enabled {
            model.kickAccessTokenUpdated()
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

struct StreamKickSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var stream: SettingsStream
    @State var streamTitle: String = ""
    @State var fetchChannelInfoFailed: Bool = false

    private func shouldFetchChannelInfo() -> Bool {
        return !stream.kickChannelName.isEmpty && (stream.kickChannelId == nil || stream.kickSlug == nil)
    }

    private func fetchChannelInfo() {
        fetchChannelInfoFailed = false
        getKickChannelInfo(channelName: stream.kickChannelName) { channelInfo in
            DispatchQueue.main.async {
                if let channelInfo {
                    self.stream.kickChannelId = String(channelInfo.chatroom.id)
                    self.stream.kickSlug = channelInfo.slug
                } else {
                    fetchChannelInfoFailed = true
                }
                if self.stream.enabled {
                    model.kickChannelNameUpdated()
                }
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

    var body: some View {
        Form {
            AuthenticationView(stream: stream)
            Section {
                TextEditNavigationView(
                    title: String(localized: "Channel name"),
                    value: stream.kickChannelName,
                    onSubmit: submitChannelName
                )
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
            if shouldFetchChannelInfo() {
                fetchChannelInfo()
            }
        }
        .navigationTitle("Kick")
    }
}
