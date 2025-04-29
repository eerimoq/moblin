import AVFoundation
import MetalPetal
import Vision

final class TripleEffect: VideoEffect {
    private let centerFilter = CIFilter.sourceOverCompositing()
    private let rightFilter = CIFilter.sourceOverCompositing()

    override func getName() -> String {
        return "triple filter"
    }

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        let size = image.extent.size
        let width = size.width / 3
        let height = size.height
        let centerImage = image.cropped(to: CGRect(
            x: width,
            y: 0,
            width: width,
            height: height
        ))
        let leftImage = centerImage.transformed(by: CGAffineTransform(
            translationX: -width,
            y: 0
        ))
        let rightImage = centerImage.transformed(by: CGAffineTransform(
            translationX: width,
            y: 0
        ))
        centerFilter.inputImage = centerImage
        centerFilter.backgroundImage = leftImage
        rightFilter.inputImage = rightImage
        rightFilter.backgroundImage = centerFilter.outputImage
        return rightFilter.outputImage ?? image
    }

    override func executeMetalPetal(_ image: MTIImage?, _: VideoEffectInfo) -> MTIImage? {
        guard let image else {
            return image
        }
        let width = image.size.width
        let height = image.size.height
        let segmentWidth = width / 3
        let leadingPosition = segmentWidth / 2
        let bottomPosition = height / 2
        guard let centerImage = image.cropped(to: .pixel(.init(
            x: segmentWidth,
            y: 0,
            width: segmentWidth,
            height: height
        ))) else {
            return image
        }
        let filter = MTIMultilayerCompositingFilter()
        filter.inputBackgroundImage = image
        filter.layers = [
            .init(content: centerImage, position: .init(x: leadingPosition, y: bottomPosition)),
            .init(
                content: centerImage,
                position: .init(x: leadingPosition + 2 * segmentWidth, y: bottomPosition)
            ),
        ]
        return filter.outputImage
    }
}
