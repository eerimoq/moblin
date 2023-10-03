import AVFoundation
import HaishinKit
import UIKit

final class SepiaEffect: VideoEffect {
    private let filter = CIFilter.sepiaTone()

    override func execute(_ image: CIImage, info _: CMSampleBuffer?) -> CIImage {
        filter.inputImage = image
        filter.intensity = 0.9
        return filter.outputImage ?? image
    }
}
