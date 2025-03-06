import SwiftUI
@preconcurrency import WebKit

class WebBrowserController: UIViewController, ObservableObject {
    @Published var showAlert = false
}

extension WebBrowserController: WKUIDelegate {
    func webView(_: WKWebView,
                 runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame _: WKFrameInfo,
                 completionHandler: @escaping () -> Void)
    {
        showAlert = true
        let alertController = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Ok", style: .default) { _ in
            self.showAlert = false
            completionHandler()
        })
        present(alertController, animated: true)
    }

    func webView(_: WKWebView,
                 runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame _: WKFrameInfo,
                 completionHandler: @escaping (Bool) -> Void)
    {
        showAlert = true
        let alertController = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
            self.showAlert = false
            completionHandler(false)
        }))
        alertController.addAction(UIAlertAction(title: "Ok", style: .default, handler: { _ in
            self.showAlert = false
            completionHandler(true)
        }))
        present(alertController, animated: true, completion: nil)
    }

    func webView(_: WKWebView,
                 runJavaScriptTextInputPanelWithPrompt prompt: String,
                 defaultText: String?,
                 initiatedByFrame _: WKFrameInfo,
                 completionHandler: @escaping (String?) -> Void)
    {
        showAlert = true
        let alertController = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
        alertController.addTextField { textField in
            textField.text = defaultText
        }
        alertController.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { _ in
            self.showAlert = false
            completionHandler(nil)
        }))
        alertController.addAction(UIAlertAction(title: "Ok", style: .default, handler: { _ in
            self.showAlert = false
            if let text = alertController.textFields?.first?.text {
                completionHandler(text)
            } else {
                completionHandler(defaultText)
            }
        }))
        present(alertController, animated: true, completion: nil)
    }
}
