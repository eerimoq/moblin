import AVFoundation
import HaishinKit
import SwiftUI
import UIKit
import WebKit

private let browserQueue = DispatchQueue(label: "com.eerimoq.widget.browser")

final class BrowserEffect: VideoEffect {
    private let filter = CIFilter.sourceOverCompositing()
    let wkwebView: WKWebView
    var overlay: CIImage?
    var image: UIImage?
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    init(url: URL, widget: SettingsSceneWidget, videoSize: CGSize) {
        x = (videoSize.width * widget.x) / 100
        y = (videoSize.height * widget.y) / 100
        width = (videoSize.width * widget.width) / 100
        height = (videoSize.height * widget.height) / 100
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        wkwebView = WKWebView(
            frame: CGRect(x: 0, y: 0, width: width, height: height),
            configuration: configuration
        )
        wkwebView.isOpaque = false
        wkwebView.backgroundColor = .clear
        wkwebView.scrollView.backgroundColor = .clear
        wkwebView.load(URLRequest(url: url))
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
