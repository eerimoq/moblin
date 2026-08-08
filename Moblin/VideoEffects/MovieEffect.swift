import CoreImage
import MetalPetal

final class MovieEffect: VideoEffect, @unchecked Sendable {
    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        image
            .cropped(to: CGRect(x: 0,
                                y: image.extent.height / 6,
                                width: image.extent.width,
                                height: 2 * image.extent.height / 3))
            .composited(over: CIImage.black.cropped(to: image.extent))
    }

    override func executeMetalPetal(_ image: MTIImage, _: VideoEffectInfo) -> MTIImage {
        let size = image.extent.size
        let barSize = CGSize(width: size.width, height: size.height / 6)
        let filter = MTIMultilayerCompositingFilter()
        filter.inputBackgroundImage = image
        filter.layers = [
            .init(content: .black,
                  position: CGPoint(x: size.width / 2, y: barSize.height / 2),
                  size: barSize),
            .init(content: .black,
                  position: CGPoint(x: size.width / 2, y: size.height - barSize.height / 2),
                  size: barSize),
        ]
        return filter.outputImage ?? image
    }
}
