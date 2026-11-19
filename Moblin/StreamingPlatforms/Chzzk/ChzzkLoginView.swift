import SwiftUI
import WebKit

struct ChzzkLoginView: View {
    let model: Model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            if let request = model.chzzkLoginRequest {
                ChzzkLoginBrowser(url: request.url, completed: model.chzzkLoginCompleted)
                    .navigationTitle("CHZZK")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") {
                                dismiss()
                            }
                        }
                    }
            }
        }
    }
}

private struct ChzzkLoginBrowser: UIViewRepresentable {
    let url: URL
    let completed: (URL?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(completed: completed)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.load(URLRequest(url: url))
        return view
    }

    func updateUIView(_: WKWebView, context _: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        let completed: (URL?) -> Void

        init(completed: @escaping (URL?) -> Void) {
            self.completed = completed
        }

        func webView(_: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void)
        {
            if let url = navigationAction.request.url, url.host == "localhost" {
                decisionHandler(.cancel)
                completed(url)
            } else {
                decisionHandler(.allow)
            }
        }

        func webView(_: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError error: Error) {
            if (error as NSError).code != NSURLErrorCancelled {
                completed(nil)
            }
        }
    }
}
