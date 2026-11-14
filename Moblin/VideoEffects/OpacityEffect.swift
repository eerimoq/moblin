import CoreImage
import MetalPetal

final class OpacityEffect: VideoEffect, @unchecked Sendable {
    private var opacity: Double = 1.0
    private let filterMetalPetal = MTIOpacityFilter()

    func setOpacity(opacity: Double) {
        processorPipelineQueue.async {
            self.opacity = opacity
        }
    }

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        let filter = CIFilter.colorMatrix()
        filter.aVector = .init(x: 0, y: 0, z: 0, w: opacity)
        filter.inputImage = image
        return filter.outputImage ?? image
    }

    override func executeMetalPetal(_ image: MTIImage, _: VideoEffectInfo) -> MTIImage {
        filterMetalPetal.inputImage = image
        filterMetalPetal.opacity = Float(opacity)
        return filterMetalPetal.outputImage ?? image
    }
}
