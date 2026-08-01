import CoreImage
import MetalPetal

final class FourThreeEffect: VideoEffect, @unchecked Sendable {
    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        image
            .cropped(to: CGRect(x: image.extent.width / 8,
                                y: 0,
                                width: 3 * image.extent.width / 4,
                                height: image.extent.height))
            .composited(over: CIImage.black.cropped(to: image.extent))
    }

    override func executeMetalPetal(_ image: MTIImage, _: VideoEffectInfo) -> MTIImage {
        let size = image.extent.size
        let barSize = CGSize(width: size.width / 8, height: size.height)
        let filter = MultilayerCompositingFilter()
        filter.inputBackgroundImage = image
        filter.layers = [
            .content(.black, modifier: { layer in
                layer.size = barSize
                layer.position = CGPoint(x: barSize.width / 2, y: size.height / 2)
            }),
            .content(.black, modifier: { layer in
                layer.size = barSize
                layer.position = CGPoint(x: size.width - barSize.width / 2, y: size.height / 2)
            }),
        ]
        return filter.outputImage ?? image
    }
}
