import AVFoundation
import CoreImage
import Vision

final class TwinEffect: VideoEffect {
    private let filter = CIFilter.sourceOverCompositing()

    override func getName() -> String {
        return "Twin filter"
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
        let leftImage = centerImage.translated(x: -width / 2, y: 0)
        let rightImage = centerImage
            .scaled(x: -1, y: 1)
            .translated(x: 5 * width / 2, y: 0)
        filter.inputImage = rightImage
        filter.backgroundImage = leftImage
        return filter.outputImage ?? image
    }
}
