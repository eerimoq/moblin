import AVFoundation
import HaishinKit
import SwiftUI
import UIKit
import WebKit

private let textQueue = DispatchQueue(label: "com.eerimoq.widget.text")

final class TextEffect: VideoEffect {
    private let filter = CIFilter.sourceOverCompositing()
    private var format: String
    private var fontSize: CGFloat
    var x: Double
    var y: Double
    private var overlay: CIImage?
    private var image: UIImage?
    private var nextUpdateTime = -1.0

    init(format: String, fontSize: CGFloat) {
        self.format = format
        self.fontSize = fontSize
        self.x = 0
        self.y = 0
    }

    private func formatted() -> String {
        return Date().formatted(.dateTime.hour().minute().second())
    }

    private func updateOverlay(size: CGSize, time: Double) {
        guard time > nextUpdateTime else {
            return
        }
        if nextUpdateTime == -1.0 {
            nextUpdateTime = time
        }
        nextUpdateTime += 1
        DispatchQueue.main.async {
            let text = Text(self.formatted())
                .font(.system(size: self.fontSize))
            let renderer = ImageRenderer(content: text)
            let image = renderer.uiImage
            textQueue.sync {
                self.image = image
            }
        }
        var newImage: UIImage?
        textQueue.sync {
            if self.image != nil {
                newImage = self.image
                self.image = nil
            }
        }
        guard let newImage else {
            return
        }
        UIGraphicsBeginImageContext(size)
        let x = (size.width * self.x) / 100
        let y = (size.height * self.y) / 100
        newImage.draw(at: CGPoint(x: x, y: y))
        overlay = CIImage(
            image: UIGraphicsGetImageFromCurrentImageContext()!,
            options: nil
        )
        UIGraphicsEndImageContext()
    }

    override func execute(_ image: CIImage, info: CMSampleBuffer?) -> CIImage {
        guard let info else {
            return image
        }
        updateOverlay(size: image.extent.size, time: info.presentationTimeStamp.seconds)
        filter.inputImage = overlay
        filter.backgroundImage = image
        return filter.outputImage ?? image
    }
}
