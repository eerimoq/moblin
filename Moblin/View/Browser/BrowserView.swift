import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let url: URL?

    func makeUIView(context _: Context) -> WKWebView {
        return WKWebView()
    }

    func updateUIView(_ webView: WKWebView, context _: Context) {
        guard let url = url else {
            return
        }
        let request = URLRequest(url: url)
        webView.load(request)
    }
}

struct BrowserView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        VStack(spacing: 0) {
            TextField("", text: $model.browserUrl)
                .padding(2)
                .border(.black)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .padding(3)
                .font(.system(size: 22))
                .background(.white)
            WebView(url: URL(string: model.browserUrl))
        }
    }
}
