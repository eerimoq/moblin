import AVFoundation
import HaishinKit
import UIKit

final class BloomEffect: VideoEffect {
    private let filter = CIFilter.bloom()

    override func execute(_ image: CIImage, info _: CMSampleBuffer?) -> CIImage {
        filter.inputImage = image
        filter.intensity = 1
        filter.radius = 10
        return filter.outputImage ?? image
    }
}
