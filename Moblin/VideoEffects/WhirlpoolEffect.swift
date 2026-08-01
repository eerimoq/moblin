import CoreImage
import MetalPetal
import simd

final class WhirlpoolEffect: VideoEffect, @unchecked Sendable {
    private let filterMetalPetal = MTITwirlDistortionFilter()
    private var angle: Float

    init(angle: Float) {
        self.angle = angle
    }

    func setSettings(angle: Float) {
        processorPipelineQueue.async {
            self.angle = angle
        }
    }

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        let filter = CIFilter.twirlDistortion()
        filter.inputImage = image
        filter.angle = angle
        filter.radius = Float(min(image.extent.width, image.extent.height) / 1.9)
        filter.center = CGPoint(x: image.extent.width / 2, y: image.extent.height / 2)
        return filter.outputImage?.cropped(to: image.extent) ?? image
    }

    override func executeMetalPetal(_ image: MTIImage, _: VideoEffectInfo) -> MTIImage {
        filterMetalPetal.inputImage = image
        filterMetalPetal.angle = angle
        filterMetalPetal.radius = Float(min(image.extent.width, image.extent.height) / 1.9)
        filterMetalPetal.center = simd_make_float2(Float(image.extent.width / 2),
                                                   Float(image.extent.height / 2))
        return filterMetalPetal.outputImage ?? image
    }
}
