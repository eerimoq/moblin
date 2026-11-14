import CoreImage
import MetalPetal

final class TripleEffect: VideoEffect, @unchecked Sendable {
    private let centerFilter = CIFilter.sourceOverCompositing()
    private let rightFilter = CIFilter.sourceOverCompositing()

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
        let leftImage = centerImage.translated(x: -width, y: 0)
        let rightImage = centerImage.translated(x: width, y: 0)
        centerFilter.inputImage = centerImage
        centerFilter.backgroundImage = leftImage
        rightFilter.inputImage = rightImage
        rightFilter.backgroundImage = centerFilter.outputImage
        return rightFilter.outputImage ?? image
    }

    override func executeMetalPetal(_ image: MTIImage, _: VideoEffectInfo) -> MTIImage {
        let size = image.extent.size
        let width = size.width / 3
        let height = size.height
        let centerRegion = CGRect(x: width, y: 0, width: width, height: height)
        let filter = MTIMultilayerCompositingFilter()
        filter.inputBackgroundImage = image
        filter.layers = (0 ..< 3).map { index in
            .init(content: image,
                  contentRegion: centerRegion,
                  position: CGPoint(x: (Double(index) + 0.5) * width, y: height / 2),
                  size: CGSize(width: width, height: height))
        }
        return filter.outputImage ?? image
    }
}
