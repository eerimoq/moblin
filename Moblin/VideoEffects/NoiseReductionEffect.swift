import AVFoundation
import CoreImage.CIFilterBuiltins
import Vision

final class NoiseReductionEffect: VideoEffect {
    private let filter = CIFilter.noiseReduction()
    var noiseLevel: Float = 0.01
    var sharpness: Float = 2.0

    override func getName() -> String {
        return "noise reduction"
    }

    override func execute(_ image: CIImage, _: [VNFaceObservation]?) -> CIImage {
        filter.inputImage = image
        filter.noiseLevel = noiseLevel
        filter.sharpness = sharpness
        return filter.outputImage ?? image
    }
}
