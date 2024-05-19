import AVFoundation
import MetalPetal
import SwiftUI
import UIKit
import Vision

private let textQueue = DispatchQueue(label: "com.eerimoq.widget.text")

final class TextEffect: VideoEffect {
    private let filter = CIFilter.sourceOverCompositing()
    private var fontSize: CGFloat
    var x: Double
    var y: Double
    private var overlay: CIImage?
    private var overlayMetalPetal: MTIImage?
    private var image: UIImage?
    private let settingName: String
    private var nextUpdateTime = Date()

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

    private func updateOverlay(size: CGSize) {
        guard Date() > nextUpdateTime else {
            return
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
        update(image: newImage, size: size)
        updateMetalPetal(image: newImage, size: size)
    }

    private func update(image: UIImage, size: CGSize) {
        let x = (size.width * self.x) / 100
        let y = (size.height * self.y) / 100
        overlay = CIImage(image: image)?
            .transformed(by: CGAffineTransform(
                translationX: x,
                y: size.height - image.size.height - y
            ))
            .cropped(to: CGRect(x: 0, y: 0, width: size.width, height: size.height))
    }

    private func updateMetalPetal(image: UIImage, size _: CGSize) {
        guard let image = image.cgImage else {
            return
        }
        overlayMetalPetal = MTIImage(cgImage: image, isOpaque: true)
    }

    override func execute(_ image: CIImage, _: [VNFaceObservation]?) -> CIImage {
        updateOverlay(size: image.extent.size)
        filter.inputImage = overlay
        filter.backgroundImage = image
        return filter.outputImage ?? image
    }

    override func executeMetalPetal(_ image: MTIImage?, _: [VNFaceObservation]?) -> MTIImage? {
        guard let image else {
            return image
        }
        updateOverlay(size: image.size)
        guard let overlayMetalPetal else {
            return image
        }
        let x = (image.size.width * self.x) / 100 + overlayMetalPetal.size.width / 2
        let y = (image.size.height * self.y) / 100 + overlayMetalPetal.size.height / 2
        let filter = MTIMultilayerCompositingFilter()
        filter.inputBackgroundImage = image
        filter.layers = [
            .init(content: overlayMetalPetal, position: .init(x: x, y: y)),
        ]
        return filter.outputImage ?? image
    }
}
