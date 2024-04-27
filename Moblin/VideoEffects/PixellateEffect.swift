import AVFoundation
import UIKit
import Vision

final class PixellateEffect: VideoEffect {
    private let filter = CIFilter.pixellate()

    override func getName() -> String {
        return "pixellate filter"
    }

    override func execute(_ image: CIImage, _: [VNFaceObservation]?) -> CIImage {
        filter.inputImage = image
        filter.center = .init(x: 0, y: 0)
        filter.scale = 10 * (Float(image.extent.width) / 1920)
        return filter.outputImage?.cropped(to: image.extent) ?? image
    }
}
