import AVFoundation
import MetalPetal
import Vision

final class TwinEffect: VideoEffect {
    private let filter = CIFilter.sourceOverCompositing()

    override func getName() -> String {
        return "twin filter"
    }

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
        let leftImage = centerImage.transformed(by: CGAffineTransform(
            translationX: -width / 2,
            y: 0
        ))
        let rightImage = centerImage
            .transformed(by: CGAffineTransform(scaleX: -1, y: 1))
            .transformed(by: CGAffineTransform(
                translationX: 5 * width / 2,
                y: 0
            ))
        filter.inputImage = rightImage
        filter.backgroundImage = leftImage
        return filter.outputImage ?? image
    }

    override func executeMetalPetal(_ image: MTIImage?, _: VideoEffectInfo) -> MTIImage? {
        return image
    }
}
