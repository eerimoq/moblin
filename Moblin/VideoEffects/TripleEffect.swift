import AVFoundation
import HaishinKit
import UIKit

final class TripleEffect: VideoEffect {
    private let centerFilter = CIFilter.sourceOverCompositing()
    private let rightFilter = CIFilter.sourceOverCompositing()

    override func execute(_ image: CIImage, info _: CMSampleBuffer?) -> CIImage {
        // How to do this on GPU?
        let size = image.extent.size
        let width = size.width / 3
        let height = size.height
        let centerImage = image.cropped(to: CGRect(
            x: width,
            y: 0,
            width: width,
            height: height
        ))
        var leftImage = centerImage.transformed(by: CGAffineTransform(
            translationX: -width,
            y: 0
        ))
        var rightImage = centerImage.transformed(by: CGAffineTransform(
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
