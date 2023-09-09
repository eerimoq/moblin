import AVFoundation
import HaishinKit
import UIKit

final class IconEffect: VideoEffect {
    private let filter: CIFilter? = CIFilter(name: "CISourceOverCompositing")
    private var extent = CGRect.zero {
        didSet {
            if extent == oldValue {
                return
            }
            UIGraphicsBeginImageContext(extent.size)
            var image = UIImage(named: "AppIconNoBackground.png")!
            image = image.scalePreservingAspectRatio(targetSize: CGSize(width: 100, height: 110))
            image.draw(at: CGPoint(x: extent.size.width - 105, y: extent.size.height - 115))
            icon = CIImage(image: UIGraphicsGetImageFromCurrentImageContext()!, options: nil)
            UIGraphicsEndImageContext()
        }
    }
    private var icon: CIImage?

    override func execute(_ image: CIImage, info: CMSampleBuffer?) -> CIImage {
        guard let filter = filter else {
            return image
        }
        extent = image.extent
        filter.setValue(icon!, forKey: "inputImage")
        filter.setValue(image, forKey: "inputBackgroundImage")
        return filter.outputImage!
    }
}
