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

    override func execute(_ image: CIImage, _: [VNFaceObservation]?) -> CIImage {
        extent = image.extent
        filter.inputImage = overlay
        filter.backgroundImage = image
        return filter.outputImage ?? image
    }

    override func executeMetalPetal(_ image: MTIImage?, _: [VNFaceObservation]?) -> MTIImage? {
        guard let image else {
            return image
        }
        extent = image.extent
        guard let overlayMetalPetal else {
            return image
        }
        let x = (extent.size.width * self.x) / 100 + overlayMetalPetal.size.width / 2
        let y = (extent.size.height * self.y) / 100 + overlayMetalPetal.size.height / 2
        let filter = MTIMultilayerCompositingFilter()
        filter.inputBackgroundImage = image
        filter.layers = [
            .init(
                content: overlayMetalPetal,
                layoutUnit: .pixel,
                position: .init(x: x, y: y),
                size: overlayMetalPetal.size,
                rotation: 0,
                opacity: 1,
                blendMode: .normal
            ),
        ]
        return filter.outputImage ?? image
    }

    private func prepare(size: CGSize) {
        UIGraphicsBeginImageContext(size)
        let x = (size.width * self.x) / 100
        let y = (size.height * self.y) / 100
        let width = (size.width * self.width) / 100
        let height = (size.height * self.height) / 100
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
        let width = (size.width * self.width) / 100
        let height = (size.height * self.height) / 100
        overlayMetalPetal = MTIImage(cgImage: originalImage, isOpaque: true).resized(
            to: .init(width: width, height: height),
            resizingMode: .aspect
        )
    }
}
