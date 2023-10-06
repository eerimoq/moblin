import AVFoundation
import HaishinKit
import SwiftUI
import UIKit
import WebKit

private func makeFrame(width: Double, viewWidth: Double,
                       height: Double, viewHeight: Double) -> CGRect
{
    return CGRect(
        x: 0,
        y: 0,
        width: (viewWidth * width) / 100,
        height: (viewHeight * height) / 100
    )
}

struct WebPage: UIViewRepresentable {
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

final class WebPageEffect: VideoEffect {
    private let filter = CIFilter.sourceOverCompositing()
    var overlay: CIImage?
    let webPage: WebPage
    var image: UIImage?
    private var extent = CGRect.zero {
        didSet {
            if extent == oldValue {
                return
            }
            createOverlay()
        }
    }

    let x: Double
    let y: Double

    init(url: URL, x: Double, y: Double, width: Double, height: Double) {
        // Should be based on real size.
        let viewWidth = 1920.0
        let viewHeight = 1080.0
        self.x = (viewWidth * x) / 100
        self.y = (viewHeight * y) / 100
        let frame = makeFrame(
            width: width,
            viewWidth: viewWidth,
            height: height,
            viewHeight: viewHeight
        )
        webPage = WebPage(
            url: url,
            frame: frame
        )
    }

    func setImage(image: UIImage) {
        self.image = image
        createOverlay()
    }

    func createOverlay() {
        guard let image else {
            return
        }
        guard !extent.isEmpty else {
            return
        }
        UIGraphicsBeginImageContext(extent.size)
        image.draw(at: CGPoint(x: self.x, y: self.y))
        overlay = CIImage(
            image: UIGraphicsGetImageFromCurrentImageContext()!,
            options: nil
        )
        UIGraphicsEndImageContext()
    }

    override func execute(_ image: CIImage, info _: CMSampleBuffer?) -> CIImage {
        extent = image.extent
        filter.inputImage = overlay
        filter.backgroundImage = image
        return filter.outputImage ?? image
    }
}
