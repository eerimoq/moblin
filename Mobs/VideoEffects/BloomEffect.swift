import AVFoundation
import HaishinKit
import UIKit

final class BloomEffect: VideoEffect {
    private let filter = CIFilter(name: "CIBloom")

    override func execute(_ image: CIImage, info: CMSampleBuffer?) -> CIImage {
        guard let filter else {
            return image
        }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(1, forKey: kCIInputIntensityKey)
        filter.setValue(10, forKey: kCIInputRadiusKey)
        return filter.outputImage!
    }
}
