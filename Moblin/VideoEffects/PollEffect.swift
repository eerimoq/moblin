import AVFoundation
import MetalPetal
import SwiftUI
import UIKit
import Vision

private let pollQueue = DispatchQueue(label: "com.eerimoq.widget.text")

final class PollEffect: VideoEffect {
    private let filter = CIFilter.sourceOverCompositing()
    private var overlay: CIImage?
    private var overlayMetalPetal: MTIImage?
    private var image: UIImage?
    private var nextUpdateTime = ContinuousClock.now.advanced(by: .seconds(-5))
    private var text = "No votes yet"

    func updateText(text: String) {
        self.text = text
    }

    override func getName() -> String {
        return "Poll widget"
    }

    private func scaledFontSize(width: Double) -> CGFloat {
        return 30 * (width / 1920)
    }

    private func updateOverlay(size: CGSize) {
        guard nextUpdateTime < .now else {
            return
        }
        nextUpdateTime += .seconds(1)
        DispatchQueue.main.async {
            let content = HStack {
                Image(systemName: "chart.bar.xaxis")
                Text(self.text)
            }
            .padding([.trailing], 7)
            .background(.black.opacity(0.75))
            .foregroundColor(.white)
            .font(.system(size: self.scaledFontSize(width: size.width)))
            .cornerRadius(10)
            let renderer = ImageRenderer(content: content)
            let image = renderer.uiImage
            pollQueue.sync {
                self.image = image
            }
        }
        var newImage: UIImage?
        pollQueue.sync {
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
        let x = size.width - image.size.width
        overlay = CIImage(image: image)?
            .transformed(by: CGAffineTransform(
                translationX: x - 5,
                y: size.height - image.size.height - 5
            ))
            .cropped(to: CGRect(x: 0, y: 0, width: size.width, height: size.height))
    }

    private func updateMetalPetal(image: UIImage, size _: CGSize) {
        guard let image = image.cgImage else {
            return
        }
        overlayMetalPetal = MTIImage(cgImage: image, isOpaque: true)
    }

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        updateOverlay(size: image.extent.size)
        filter.inputImage = overlay
        filter.backgroundImage = image
        return filter.outputImage ?? image
    }

    override func executeMetalPetal(_ image: MTIImage?, _: VideoEffectInfo) -> MTIImage? {
        guard let image else {
            return image
        }
        updateOverlay(size: image.size)
        guard let overlayMetalPetal else {
            return image
        }
        let x = image.size.width - overlayMetalPetal.size.width / 2 - 5
        let y = overlayMetalPetal.size.height / 2 + 5
        let filter = MTIMultilayerCompositingFilter()
        filter.inputBackgroundImage = image
        filter.layers = [
            .init(content: overlayMetalPetal, position: .init(x: x, y: y)),
        ]
        return filter.outputImage ?? image
    }
}
