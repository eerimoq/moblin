import AVFoundation
import UIKit

final class GrayScaleEffect: VideoEffect {
    private let filter = CIFilter.colorMonochrome()

    override func getName() -> String {
        return "gray scale filter"
    }

    override func execute(_ image: CIImage) -> CIImage {
        filter.inputImage = image
        filter.color = CIColor(red: 0.75, green: 0.75, blue: 0.75)
        filter.intensity = 1.0
        return filter.outputImage ?? image
    }
}
