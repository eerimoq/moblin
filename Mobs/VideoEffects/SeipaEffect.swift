import AVFoundation
import HaishinKit
import UIKit

final class SeipaEffect: VideoEffect {
    private let filter = CIFilter(name: "CISepiaTone")

    override func execute(_ image: CIImage, info: CMSampleBuffer?) -> CIImage {
        guard let filter = filter else {
            return image
        }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(0.9, forKey: kCIInputIntensityKey)
        return filter.outputImage!
    }
}
