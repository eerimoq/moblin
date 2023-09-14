import AVFoundation
import HaishinKit
import UIKit

final class MovieEffect: VideoEffect {
    private let filter = CIFilter(name: "CISourceOverCompositing")
    private var extent = CGRect.zero {
        didSet {
            if extent == oldValue {
                return
            }
            let width = extent.size.width
            let height = extent.size.height / 6
            UIGraphicsBeginImageContext(extent.size)
            let context = UIGraphicsGetCurrentContext()!
            context.setFillColor(UIColor.black.cgColor)
            context.fill([
                CGRect(x: 0, y: 0, width: width, height: height),
                CGRect(x: 0, y: 5 * height, width: width, height: height),
            ])
            black = CIImage(image: UIGraphicsGetImageFromCurrentImageContext()!)
            UIGraphicsEndImageContext()
        }
    }

    private var black: CIImage?

    override func execute(_ image: CIImage, info _: CMSampleBuffer?) -> CIImage {
        guard let filter else {
            return image
        }
        extent = image.extent
        filter.setValue(black!, forKey: "inputImage")
        filter.setValue(image, forKey: "inputBackgroundImage")
        return filter.outputImage!
    }
}
