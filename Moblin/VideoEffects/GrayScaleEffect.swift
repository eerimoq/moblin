import AVFoundation
import MetalPetal
import UIKit
import Vision

final class GrayScaleEffect: VideoEffect {
    private let filter = CIFilter.colorMonochrome()

    override func getName() -> String {
        return "gray scale filter"
    }

    override func execute(_ image: CIImage, _: [VNFaceObservation]?) -> CIImage {
        filter.inputImage = image
        filter.color = CIColor(red: 0.75, green: 0.75, blue: 0.75)
        filter.intensity = 1.0
        return filter.outputImage ?? image
    }

    override func executeMetalPetal(_ image: MTIImage?, _: [VNFaceObservation]?) -> MTIImage? {
        let filter = MTISaturationFilter()
        filter.saturation = 0
        filter.inputImage = image
        return filter.outputImage
    }
}
