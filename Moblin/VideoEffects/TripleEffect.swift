import AVFoundation
import HaishinKit
import UIKit

final class TripleEffect: VideoEffect {
    private let centerFilter = CIFilter.sourceOverCompositing()
    private let rightFilter = CIFilter.sourceOverCompositing()

    override func getName() -> String {
        return "triple filter"
    }

    override func execute(_ image: CIImage, info _: CMSampleBuffer?) -> CIImage {
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
}
