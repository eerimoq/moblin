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

    private func widgetHost(for browser: Browser) -> String {
        return browser.browserEffect.host
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
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(model.browsers) { browser in
                            Button {
                                model.interactiveBrowserWidgetSelectedId = browser.id
                            } label: {
                                Text(widgetHost(for: browser))
                                    .lineLimit(1)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        browser.id == model.interactiveBrowserWidgetSelectedId
                                            ? Color.accentColor : Color.gray.opacity(0.3)
                                    )
                                    .foregroundStyle(
                                        browser.id == model.interactiveBrowserWidgetSelectedId
                                            ? .white : .primary
                                    )
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
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
