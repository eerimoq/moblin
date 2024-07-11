import AVFoundation
import MetalPetal
import UIKit
import Vision

final class ImageEffect: VideoEffect {
    private let filter = CIFilter.sourceOverCompositing()
    private var extent = CGRect.zero {
        didSet {
            guard extent != oldValue else {
                return
            }
            prepare(size: extent.size)
            prepareMetalPetal(size: extent.size)
        }
    }

    private var overlay: CIImage!
    private var overlayMetalPetal: MTIImage?
    private let originalImage: UIImage
    private let x: Double
    private let y: Double
    private let width: Double
    private let height: Double
    private let settingName: String

    init(image: UIImage, x: Double, y: Double, width: Double, height: Double, settingName: String) {
        originalImage = image
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.settingName = settingName
        super.init()
    }

    override func getName() -> String {
        return "\(settingName) image widget"
    }

    override func execute(_ image: CIImage, _: [VNFaceObservation]?, _: Bool) -> CIImage {
        extent = image.extent
        filter.inputImage = overlay
        filter.backgroundImage = image
        return filter.outputImage ?? image
    }

    override func executeMetalPetal(_ image: MTIImage?, _: [VNFaceObservation]?, _: Bool) -> MTIImage? {
        guard let image else {
            return image
        }
        extent = image.extent
        guard let overlayMetalPetal else {
            return image
        }
        let x = toPixels(self.x, extent.size.width) + overlayMetalPetal.size.width / 2
        let y = toPixels(self.y, extent.size.height) + overlayMetalPetal.size.height / 2
        let filter = MTIMultilayerCompositingFilter()
        filter.inputBackgroundImage = image
        filter.layers = [
            .init(content: overlayMetalPetal, position: .init(x: x, y: y)),
        ]
        return filter.outputImage ?? image
    }

    private func prepare(size: CGSize) {
        UIGraphicsBeginImageContext(size)
        let x = toPixels(self.x, size.width)
        let y = toPixels(self.y, size.height)
        let width = toPixels(self.width, size.width)
        let height = toPixels(self.height, size.height)
        let image = originalImage.scalePreservingAspectRatio(targetSize: CGSize(
            width: width,
            height: height
        ))
        image.draw(at: CGPoint(x: x, y: y))
        overlay = CIImage(
            image: UIGraphicsGetImageFromCurrentImageContext()!,
            options: nil
        )
        UIGraphicsEndImageContext()
    }

    private func prepareMetalPetal(size: CGSize) {
        guard let originalImage = originalImage.cgImage else {
            return
        }
        let width = toPixels(self.width, size.width)
        let height = toPixels(self.height, size.height)
        overlayMetalPetal = MTIImage(cgImage: originalImage, isOpaque: true).resized(
            to: .init(width: width, height: height),
            resizingMode: .aspect
        )
    }
}
