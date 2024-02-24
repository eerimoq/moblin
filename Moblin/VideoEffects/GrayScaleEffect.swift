import AVFoundation
import HaishinKit
import UIKit

final class GrayScaleEffect: VideoEffect {
    private let filter = CIFilter.colorMonochrome()

    override init() {
        super.init()
        name = "gray scale filter"
    }

    override func execute(_ image: CIImage, info _: CMSampleBuffer?) -> CIImage {
        filter.inputImage = image
        filter.color = CIColor(red: 0.75, green: 0.75, blue: 0.75)
        filter.intensity = 1.0
        return filter.outputImage ?? image
    }
}
