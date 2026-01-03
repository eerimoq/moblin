import SwiftUI
import WebKit

private let kickDomain = "kick.com"
private let loginUrl = URL(string: "https://kick.com/login")!
private let sessionTokenCookieName = "session_token"

struct KickLoginView: View {
    @Binding var presenting: Bool
    let onAccessToken: (String) -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Close") {
                        presenting = false
                    }
                }
                .padding()
                KickWebView {
                    onAccessToken($0)
                    presenting = false
                }
            }
            .ignoresSafeArea(.keyboard)
        }
    }
}

struct KickWebView: UIViewRepresentable {
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
        guard webView.url?.host()?.contains(kickDomain) != true else {
            return
        }
        webView.load(URLRequest(url: loginUrl))
        context.coordinator.periodicallyCheckForAccessTokenCookie(webView: webView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onAccessToken)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let onAccessToken: (String) -> Void
        private var loginButtonClicked = false
        private let timer = SimpleTimer(queue: .main)

        init(_ onAccessToken: @escaping (String) -> Void) {
            self.onAccessToken = onAccessToken
        }

        func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
            if !loginButtonClicked {
                detectAndClickLoginButton(webView)
            }
        }

        func periodicallyCheckForAccessTokenCookie(webView: WKWebView) {
            timer.startPeriodic(interval: 1) { [weak self] in
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
                        self?.onAccessToken(accessToken.removingPercentEncoding ?? accessToken)
                    }
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
                guard error == nil, result as? Bool == true else {
                    return
                }
                self.loginButtonClicked = true
            }
        }
    }
}
