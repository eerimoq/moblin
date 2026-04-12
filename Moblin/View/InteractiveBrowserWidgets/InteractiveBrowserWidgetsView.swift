import SwiftUI
import WebKit

private class BrowserWidgetContainerView: UIView {
    weak var currentWebView: UIView?
    var originalWidth: Double = 0
    var originalHeight: Double = 0
    fileprivate var appliedScale: Double = 0
    fileprivate var appliedCenter: CGPoint = .zero

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let webView = currentWebView else {
            return
        }
        let containerWidth = bounds.width
        let containerHeight = bounds.height
        guard containerWidth > 0, containerHeight > 0, originalWidth > 0, originalHeight > 0 else {
            return
        }
        let scaleX = containerWidth / originalWidth
        let scaleY = containerHeight / originalHeight
        let scale = min(scaleX, scaleY)
        let center = CGPoint(x: containerWidth / 2, y: containerHeight / 2)
        guard scale != appliedScale || center != appliedCenter else {
            return
        }
        appliedScale = scale
        appliedCenter = center
        webView.transform = .identity
        webView.frame = CGRect(x: 0, y: 0, width: originalWidth, height: originalHeight)
        webView.transform = CGAffineTransform(scaleX: scale, y: scale)
        webView.center = center
    }
}

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

    func makeUIView(context _: Context) -> BrowserWidgetContainerView {
        let container = BrowserWidgetContainerView()
        container.clipsToBounds = true
        return container
    }

    func updateUIView(_ uiView: BrowserWidgetContainerView, context: Context) {
        if context.coordinator.currentWebView !== webView {
            context.coordinator.currentWebView?.removeFromSuperview()
            context.coordinator.currentWebView?.transform = .identity
            webView.removeFromSuperview()
            uiView.addSubview(webView)
            context.coordinator.currentWebView = webView
            uiView.currentWebView = webView
            uiView.appliedScale = 0
            uiView.appliedCenter = .zero
        }
        if uiView.originalWidth != originalWidth || uiView.originalHeight != originalHeight {
            uiView.originalWidth = originalWidth
            uiView.originalHeight = originalHeight
            uiView.setNeedsLayout()
        }
    }

    static func dismantleUIView(_: BrowserWidgetContainerView, coordinator: Coordinator) {
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
        ZStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(model.browsers) { browser in
                            Button {
                                model.interactiveBrowserWidgetSelectedId = browser.id
                            } label: {
                                Text(browser.name)
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
            CloseButtonTopRightView {
                model.closeInteractiveBrowserWidgets()
            }
        }
    }
}
