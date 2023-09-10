import AVFoundation
import HaishinKit
import UIKit

final class ImageEffect: VideoEffect {
    private let filter: CIFilter? = CIFilter(name: "CISourceOverCompositing")
    private var extent = CGRect.zero {
        didSet {
            if extent == oldValue {
                return
            }
            UIGraphicsBeginImageContext(extent.size)
            var image = originalImage.scalePreservingAspectRatio(targetSize: CGSize(width: 192, height: 108))
            image.draw(at: CGPoint(x: extent.size.width - 192, y: extent.size.height - 108))
            overlay = CIImage(image: UIGraphicsGetImageFromCurrentImageContext()!, options: nil)
            UIGraphicsEndImageContext()
        }
    }
    private var overlay: CIImage?
    private var originalImage: UIImage
    
    init(image: UIImage) {
        self.originalImage = image
    }

    override func execute(_ image: CIImage, info: CMSampleBuffer?) -> CIImage {
        guard let filter = filter else {
            return image
        }
        extent = image.extent
        filter.setValue(overlay!, forKey: "inputImage")
        filter.setValue(image, forKey: "inputBackgroundImage")
        return filter.outputImage!
    }
}
