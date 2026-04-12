import SwiftUI
import WebKit

private struct BrowserWidgetWebView: UIViewRepresentable {
    let webView: WKWebView
    let originalWidth: Double
    let originalHeight: Double

    class Coordinator {
        weak var currentWebView: WKWebView?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context _: Context) -> UIView {
        let container = UIView()
        container.clipsToBounds = true
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if context.coordinator.currentWebView !== webView {
            context.coordinator.currentWebView?.removeFromSuperview()
            context.coordinator.currentWebView?.transform = .identity
            webView.removeFromSuperview()
            uiView.addSubview(webView)
            context.coordinator.currentWebView = webView
        }
        let containerWidth = uiView.bounds.width
        let containerHeight = uiView.bounds.height
        guard containerWidth > 0, containerHeight > 0 else {
            return
        }
        let scaleX = containerWidth / originalWidth
        let scaleY = containerHeight / originalHeight
        let scale = min(scaleX, scaleY)
        webView.transform = .identity
        webView.frame = CGRect(x: 0, y: 0, width: originalWidth, height: originalHeight)
        webView.transform = CGAffineTransform(scaleX: scale, y: scale)
        webView.center = CGPoint(x: containerWidth / 2, y: containerHeight / 2)
    }

    static func dismantleUIView(_: UIView, coordinator: Coordinator) {
        coordinator.currentWebView?.removeFromSuperview()
        coordinator.currentWebView?.transform = .identity
        coordinator.currentWebView = nil
    }
}

struct InteractiveBrowserWidgetsView: View {
    @EnvironmentObject var model: Model

    private func selectedBrowser() -> Browser? {
        if let selectedId = model.interactiveBrowserWidgetSelectedId,
           let browser = model.browsers.first(where: { $0.id == selectedId })
        {
            return browser
        }
        return model.browsers.first
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    model.closeInteractiveBrowserWidgets()
                } label: {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .padding(10)
                }
                Spacer()
                Text("Browser widgets")
                    .font(.headline)
                Spacer()
                Color.clear
                    .frame(width: 44, height: 44)
            }
            .padding(.horizontal, 4)
            if model.browsers.count > 1 {
                Picker("", selection: Binding(
                    get: { model.interactiveBrowserWidgetSelectedId ?? model.browsers.first?.id ?? UUID() },
                    set: { model.interactiveBrowserWidgetSelectedId = $0 }
                )) {
                    ForEach(model.browsers) { browser in
                        Text(browser.name).tag(browser.id)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            if let browser = selectedBrowser() {
                BrowserWidgetWebView(
                    webView: browser.browserEffect.webView,
                    originalWidth: browser.browserEffect.width,
                    originalHeight: browser.browserEffect.height
                )
            } else {
                VStack {
                    Spacer()
                    Text("No browser widgets available")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .background(.black.opacity(0.9))
    }
}
