import AVFoundation
import CoreImage.CIFilterBuiltins

final class NoiseReductionEffect: VideoEffect {
    private let filter = CIFilter.noiseReduction()
    var noiseLevel: Float = 0.01
    var sharpness: Float = 2.0

    override func getName() -> String {
        return "noise reduction"
    }

    override func execute(_ image: CIImage) -> CIImage {
        filter.inputImage = image
        filter.noiseLevel = noiseLevel
        filter.sharpness = sharpness
        return filter.outputImage ?? image
    }
}
