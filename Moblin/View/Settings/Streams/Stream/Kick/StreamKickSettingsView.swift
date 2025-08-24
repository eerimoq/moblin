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

struct StreamKickSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var stream: SettingsStream

    func submitChannelName(value: String) {
        stream.kickChannelName = value
        if stream.enabled {
            model.kickChannelNameUpdated()
        }
    }

    func submitStreamTitle(value: String) {
        model.setKickStreamTitle(title: value)
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
            }
            Section {
                TextEditNavigationView(
                    title: String(localized: "Stream title"),
                    value: stream.kickStreamTitle,
                    onSubmit: submitStreamTitle
                )
            }
        }
        .onAppear {
            if stream.kickLoggedIn && !stream.kickChannelName.isEmpty {
                model.getKickStreamTitle()
            }
        }
        .navigationTitle("Kick")
    }
}
