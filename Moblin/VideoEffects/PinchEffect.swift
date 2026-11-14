import CoreImage
import MetalPetal
import simd

final class PinchEffect: VideoEffect, @unchecked Sendable {
    private let filterMetalPetal = MTIPinchDistortionFilter()
    private var scale: Float

    init(scale: Float) {
        self.scale = scale
    }

    func setSettings(scale: Float) {
        processorPipelineQueue.async {
            self.scale = scale
        }
    }

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        let filter = CIFilter.pinchDistortion()
        filter.inputImage = image
        filter.radius = Float(min(image.extent.width, image.extent.height) / 2)
        filter.scale = scale
        filter.center = CGPoint(x: image.extent.width / 2, y: image.extent.height / 2)
        return filter.outputImage?.cropped(to: image.extent) ?? image
    }

    override func executeMetalPetal(_ image: MTIImage, _: VideoEffectInfo) -> MTIImage {
        filterMetalPetal.inputImage = image
        filterMetalPetal.radius = Float(min(image.extent.width, image.extent.height) / 2)
        filterMetalPetal.scale = scale
        filterMetalPetal.center = .init(Float(image.extent.width / 2),
                                        Float(image.extent.height / 2))
        return filterMetalPetal.outputImage ?? image
    }
}
