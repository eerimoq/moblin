import CoreImage
import MetalPetal

final class TwinEffect: VideoEffect, @unchecked Sendable {
    private let filter = CIFilter.sourceOverCompositing()

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        let size = image.extent.size
        let width = size.width / 2
        let height = size.height
        let centerImage = image.cropped(to: CGRect(
            x: width / 2,
            y: 0,
            width: width,
            height: height
        ))
        let leftImage = centerImage.translated(x: -width / 2, y: 0)
        let rightImage = centerImage
            .scaled(x: -1, y: 1)
            .translated(x: 5 * width / 2, y: 0)
        filter.inputImage = rightImage
        filter.backgroundImage = leftImage
        return filter.outputImage ?? image
    }

    override func executeMetalPetal(_ image: MTIImage, _: VideoEffectInfo) -> MTIImage {
        let size = image.extent.size
        let width = size.width / 2
        let height = size.height
        let centerRegion = CGRect(x: width / 2, y: 0, width: width, height: height)
        let layerSize = CGSize(width: width, height: height)
        let filter = MultilayerCompositingFilter()
        filter.inputBackgroundImage = image
        filter.layers = [
            .content(image, modifier: { layer in
                layer.contentRegion = centerRegion
                layer.size = layerSize
                layer.position = CGPoint(x: width / 2, y: height / 2)
            }),
            .content(image, modifier: { layer in
                layer.contentRegion = centerRegion
                layer.size = layerSize
                layer.position = CGPoint(x: 3 * width / 2, y: height / 2)
                layer.contentFlipOptions = .flipHorizontally
            }),
        ]
        return filter.outputImage ?? image
    }
}
