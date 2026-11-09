import Foundation
import WebKit

@MainActor
class WebBrowserState: ObservableObject {
    @Published var isSmall = false
}

func makeWebBrowserUrl(text: String) -> URL? {
    if let url = URL(string: text), let scheme = url.scheme, !scheme.isEmpty {
        return url
    }
    if text.contains("."), let url = URL(string: "https://\(text)") {
        return url
    }
    var components = URLComponents()
    components.scheme = "https"
    components.host = "www.google.com"
    components.path = "/search"
    components.queryItems = [URLQueryItem(name: "q", value: text)]
    let query = components.percentEncodedQuery
    components.percentEncodedQuery = query?.replacingOccurrences(of: "+", with: "%2B")
    return components.url
}

extension Model {
    func loadWebBrowserUrl() {
        guard let url = makeWebBrowserUrl(text: webBrowserUrl) else {
            return
        }
        webBrowser?.load(URLRequest(url: url))
    }

    func loadWebBrowserHome() {
        webBrowserUrl = database.webBrowser.home
        loadWebBrowserUrl()
    }

    func loadWebBrowserPage(url: String) {
        webBrowserUrl = url
        loadWebBrowserUrl()
    }

    func getWebBrowser() -> WKWebView {
        if webBrowser == nil {
            let configuration = WKWebViewConfiguration()
            configuration.allowsInlineMediaPlayback = true
            configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
            configuration.setHttpProxy(endpoint: getHttpProxyServerEndpoint())
            webBrowser = WKWebView(frame: .zero, configuration: configuration)
            webBrowser?.navigationDelegate = self
            webBrowser?.uiDelegate = webBrowserController
            DispatchQueue.main.async {
                self.loadWebBrowserHome()
            }
        }
        return webBrowser!
    }

    func setWebBrowserProxy() {
        webBrowser?.configuration.setHttpProxy(endpoint: getHttpProxyServerEndpoint())
    }
}

extension Model: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
        webBrowserUrl = webView.url?.absoluteString ?? ""
        database.webBrowser.home = webBrowserUrl
    }
}
