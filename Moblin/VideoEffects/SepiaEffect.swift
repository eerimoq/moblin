import AVFoundation
import UIKit
import Vision

final class SepiaEffect: VideoEffect {
    private let filter = CIFilter.sepiaTone()

    override func getName() -> String {
        return "sepia filter"
    }

    override func execute(_ image: CIImage, _: [VNFaceObservation]?, _: Bool) -> CIImage {
        filter.inputImage = image
        filter.intensity = 0.9
        return filter.outputImage ?? image
    }
}
