import AVFoundation
import MetalPetal
import UIKit
import Vision

final class MovieEffect: VideoEffect {
    override func getName() -> String {
        return "movie filter"
    }

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        return image
            .cropped(to: CGRect(x: 0,
                                y: image.extent.height / 6,
                                width: image.extent.width,
                                height: 2 * image.extent.height / 3))
            .composited(over: CIImage.black.cropped(to: image.extent))
    }

    override func executeMetalPetal(_ image: MTIImage?, _: VideoEffectInfo) -> MTIImage? {
        guard let image else {
            return image
        }
        let blackWidth = image.size.width
        let blackHeight = image.size.height / 6
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
                position: .init(x: Int(blackWidth / 2), y: Int(image.size.height - blackHeight / 2))
            ),
        ]
        return filter.outputImage
    }
}
