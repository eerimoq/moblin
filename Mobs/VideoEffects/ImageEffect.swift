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
            let x = (extent.size.width * self.x) / 100
            let y = (extent.size.height * self.y) / 100
            let width = (extent.size.width * self.width) / 100
            let height = (extent.size.height * self.height) / 100
            let image = originalImage.scalePreservingAspectRatio(targetSize: CGSize(width: width, height: height))
            image.draw(at: CGPoint(x: x, y: y))
            overlay = CIImage(image: UIGraphicsGetImageFromCurrentImageContext()!, options: nil)
            UIGraphicsEndImageContext()
        }
    }
    private var overlay: CIImage?
    private let originalImage: UIImage
    private let x: Double
    private let y: Double
    private let width: Double
    private let height: Double
    
    init(image: UIImage, x: Double, y: Double, width: Double, height: Double) {
        self.originalImage = image
        self.x = x
        self.y = y
        self.width = width
        self.height = height
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
