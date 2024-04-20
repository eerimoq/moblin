import AVFoundation
import SwiftUI
import UIKit

private let textQueue = DispatchQueue(label: "com.eerimoq.widget.text")

final class TextEffect: VideoEffect {
    private let filter = CIFilter.sourceOverCompositing()
    private var fontSize: CGFloat
    var x: Double
    var y: Double
    private var overlay: CIImage?
    private var image: UIImage?
    private var nextUpdateTime = -1.0
    private let settingName: String

    init(format _: String, fontSize: CGFloat, settingName: String) {
        self.fontSize = fontSize
        self.settingName = settingName
        x = 0
        y = 0
        super.init()
    }

    override func getName() -> String {
        return "\(settingName) browser widget"
    }

    private func formatted() -> String {
        return Date().formatted(.dateTime.hour().minute().second())
    }

    private func scaledFontSize(width: Double) -> CGFloat {
        return fontSize * (width / 1920)
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
                .background(.black)
                .foregroundColor(.white)
                .font(.system(size: self.scaledFontSize(width: size.width)))
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
        let x = (size.width * self.x) / 100
        let y = (size.height * self.y) / 100
        overlay = CIImage(image: newImage)
        if overlay != nil {
            overlay = overlay!.transformed(by: CGAffineTransform(
                translationX: x,
                y: size.height - newImage.size.height - y
            ))
            if overlay != nil {
                overlay = overlay!.cropped(to: CGRect(x: 0, y: 0, width: size.width, height: size.height))
            }
        }
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
