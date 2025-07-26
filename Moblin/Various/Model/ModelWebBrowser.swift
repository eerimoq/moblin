import Foundation
import WebKit

extension Model {
    private func getWebBrowserUrl() -> URL? {
        if let url = URL(string: webBrowserUrl), let scehme = url.scheme, !scehme.isEmpty {
            return url
        }
        if webBrowserUrl.contains("."), let url = URL(string: "https://\(webBrowserUrl)") {
            return url
        }
        return URL(string: "https://www.google.com/search?q=\(webBrowserUrl)")
    }

    func loadWebBrowserUrl() {
        guard let url = getWebBrowserUrl() else {
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
            webBrowser = WKWebView()
            webBrowser?.navigationDelegate = self
            webBrowser?.uiDelegate = webBrowserController
            webBrowser?.configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
            DispatchQueue.main.async {
                self.loadWebBrowserHome()
            }
        }
        return webBrowser!
    }
}

extension Model: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
        webBrowserUrl = webView.url?.absoluteString ?? ""
        database.webBrowser.home = webBrowserUrl
    }
}
