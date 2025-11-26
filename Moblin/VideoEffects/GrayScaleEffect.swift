import AVFoundation
import UIKit
import Vision

final class GrayScaleEffect: VideoEffect {
    private let filter = CIFilter.colorMonochrome()

    override func getName() -> String {
        return "Gray scale filter"
    }

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        filter.inputImage = image
        filter.color = CIColor(red: 0.75, green: 0.75, blue: 0.75)
        filter.intensity = 1.0
        return filter.outputImage ?? image
    }
}
