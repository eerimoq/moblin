import AVFoundation
import HaishinKit
import UIKit

final class PixellateEffect: VideoEffect {
    private let filter = CIFilter.pixellate()

    override init() {
        super.init()
        name = "pixellate filter"
    }

    override func execute(_ image: CIImage, info _: CMSampleBuffer?) -> CIImage {
        filter.inputImage = image
        filter.center = .init(x: 0, y: 0)
        filter.scale = 10 * (Float(image.extent.width) / 1920)
        return filter.outputImage?.cropped(to: image.extent) ?? image
    }
}
