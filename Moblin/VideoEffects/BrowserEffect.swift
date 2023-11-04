import AVFoundation
import HaishinKit
import SwiftUI
import UIKit
import WebKit

private let browserQueue = DispatchQueue(label: "com.eerimoq.widget.browser")

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
        wkwebView.isOpaque = false
        wkwebView.backgroundColor = .clear
        wkwebView.scrollView.backgroundColor = .clear
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
        browserQueue.sync {
            self.image = image
        }
    }

    private func updateOverlay(size: CGSize) {
        var newImage: UIImage?
        browserQueue.sync {
            if self.image != nil {
                newImage = self.image
                self.image = nil
            }
        }
        guard let newImage else {
            return
        }
        UIGraphicsBeginImageContext(size)
        newImage.draw(at: CGPoint(x: x, y: y))
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
