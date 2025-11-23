import AVFoundation
import CoreImage
import Vision

final class TripleEffect: VideoEffect {
    private let centerFilter = CIFilter.sourceOverCompositing()
    private let rightFilter = CIFilter.sourceOverCompositing()

    override func getName() -> String {
        return "Triple filter"
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
        let leftImage = centerImage.translated(x: -width, y: 0)
        let rightImage = centerImage.translated(x: width, y: 0)
        centerFilter.inputImage = centerImage
        centerFilter.backgroundImage = leftImage
        rightFilter.inputImage = rightImage
        rightFilter.backgroundImage = centerFilter.outputImage
        return rightFilter.outputImage ?? image
    }
}
