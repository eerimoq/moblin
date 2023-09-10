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
            let x = (extent.size.width * CGFloat(self.x)) / 100
            let y = (extent.size.height * CGFloat(self.y)) / 100
            let width = (extent.size.width * CGFloat(self.width)) / 100
            let height = (extent.size.height * CGFloat(self.height)) / 100
            var image = originalImage.scalePreservingAspectRatio(targetSize: CGSize(width: width, height: height))
            image.draw(at: CGPoint(x: x, y: y))
            overlay = CIImage(image: UIGraphicsGetImageFromCurrentImageContext()!, options: nil)
            UIGraphicsEndImageContext()
        }
    }
    private var overlay: CIImage?
    private var originalImage: UIImage
    private var x: Int
    private var y: Int
    private var width: Int
    private var height: Int
    
    init(image: UIImage, x: Int, y: Int, width: Int, height: Int) {
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
