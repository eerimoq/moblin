import AVFoundation
import MetalPetal
import UIKit
import Vision

final class FourThreeEffect: VideoEffect {
    private let filter = CIFilter.sourceOverCompositing()
    private var extent = CGRect.zero {
        didSet {
            guard extent != oldValue else {
                return
            }
            let width = extent.size.width / 8
            let height = extent.size.height
            UIGraphicsBeginImageContext(extent.size)
            let context = UIGraphicsGetCurrentContext()!
            context.setFillColor(UIColor.black.cgColor)
            context.fill([
                CGRect(x: 0, y: 0, width: width, height: height),
                CGRect(x: extent.size.width - width, y: 0, width: width, height: height),
            ])
            black = CIImage(image: UIGraphicsGetImageFromCurrentImageContext()!)
            UIGraphicsEndImageContext()
        }
    }

    private var black: CIImage?

    override func getName() -> String {
        return "movie filter"
    }

    override func execute(_ image: CIImage, _: [VNFaceObservation]?, _: Bool) -> CIImage {
        extent = image.extent
        filter.inputImage = black!
        filter.backgroundImage = image
        return filter.outputImage ?? image
    }

    override func executeMetalPetal(_ image: MTIImage?, _: [VNFaceObservation]?, _: Bool) -> MTIImage? {
        guard let image else {
            return image
        }
        let blackWidth = image.size.width / 8
        let blackHeight = image.size.height
        let blackImage = MTIImage(
            color: .black,
            sRGB: false,
            size: .init(width: blackWidth, height: blackHeight)
        )
        let filter = MTIMultilayerCompositingFilter()
        filter.inputBackgroundImage = image
        filter.layers = [
            .init(content: blackImage, position: .init(x: Int(blackWidth / 2), y: Int(blackHeight / 2))),
            .init(
                content: blackImage,
                position: .init(x: Int(image.size.width - blackWidth / 2), y: Int(blackHeight / 2))
            ),
        ]
        return filter.outputImage
    }
}
