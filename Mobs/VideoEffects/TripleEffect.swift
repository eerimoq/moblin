import AVFoundation
import HaishinKit
import UIKit

final class TripleEffect: VideoEffect {
    override func execute(_ image: CIImage, info _: CMSampleBuffer?) -> CIImage {
        // How to do this on GPU?
        let size = image.extent.size
        let width = size.width / 3
        let height = size.height
        let centerImage = UIImage(ciImage: image.cropped(to: CGRect(
            x: width,
            y: 0,
            width: width,
            height: height
        )))
        UIGraphicsBeginImageContext(size)
        centerImage.draw(at: CGPoint(x: 0, y: 0))
        centerImage.draw(at: CGPoint(x: width, y: 0))
        centerImage.draw(at: CGPoint(x: 2 * width, y: 0))
        let outputImage = CIImage(
            image: UIGraphicsGetImageFromCurrentImageContext()!,
            options: nil
        )
        UIGraphicsEndImageContext()
        return outputImage ?? image
    }
}
