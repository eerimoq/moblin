import AVFoundation
import MetalPetal
import UIKit
import Vision

final class FourThreeEffect: VideoEffect {
    override func getName() -> String {
        return "4:3 filter"
    }

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        return image
            .cropped(to: CGRect(x: image.extent.width / 8,
                                y: 0,
                                width: 3 * image.extent.width / 4,
                                height: image.extent.height))
            .composited(over: CIImage.black.cropped(to: image.extent))
    }

    override func executeMetalPetal(_ image: MTIImage?, _: VideoEffectInfo) -> MTIImage? {
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
