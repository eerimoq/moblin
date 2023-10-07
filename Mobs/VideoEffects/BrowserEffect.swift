import AVFoundation
import HaishinKit
import SwiftUI
import UIKit
import WebKit

struct Browser: UIViewRepresentable {
    let wkwebView: WKWebView

    init(url: URL, frame: CGRect) {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.allowsPictureInPictureMediaPlayback = false
        configuration.mediaTypesRequiringUserActionForPlayback = []
        wkwebView = WKWebView(
            frame: frame,
            configuration: configuration
        )
        let request = URLRequest(url: url)
        wkwebView.load(request)
    }

    func makeUIView(context _: Context) -> WKWebView {
        return wkwebView
    }

    func updateUIView(_: WKWebView, context _: Context) {}
}

final class BrowserEffect: VideoEffect {
    private let filter = CIFilter.sourceOverCompositing()
    let browser: Browser
    var overlay: CIImage?
    var image: UIImage?
    let x: Double
    let y: Double

    init(url: URL, widget: SettingsSceneWidget, videoSize: CGSize) {
        x = (videoSize.width * widget.x) / 100
        y = (videoSize.height * widget.y) / 100
        browser = Browser(
            url: url,
            frame: CGRect(
                x: 0,
                y: 0,
                width: (videoSize.width * widget.width) / 100,
                height: (videoSize.height * widget.height) / 100
            )
        )
    }

    func setImage(image: UIImage) {
        self.image = image
    }

    private func updateOverlay(size: CGSize) {
        guard let image else {
            return
        }
        self.image = nil
        UIGraphicsBeginImageContext(size)
        image.draw(at: CGPoint(x: x, y: y))
        overlay = CIImage(
            image: UIGraphicsGetImageFromCurrentImageContext()!,
            options: nil
        )
        UIGraphicsEndImageContext()
    }

    override func execute(_ image: CIImage, info _: CMSampleBuffer?) -> CIImage {
        updateOverlay(size: image.extent.size)
        filter.inputImage = overlay
        filter.backgroundImage = image
        return filter.outputImage ?? image
    }
}
