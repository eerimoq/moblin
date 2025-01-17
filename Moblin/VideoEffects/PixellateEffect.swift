import AVFoundation
import MetalPetal
import UIKit
import Vision

final class PixellateEffect: VideoEffect {
    private let filter = CIFilter.pixellate()
    var strength: Atomic<Float>

    init(strength: Float) {
        self.strength = .init(strength)
    }

    override func getName() -> String {
        return "pixellate filter"
    }

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        filter.inputImage = image
        filter.center = .init(x: 0, y: 0)
        filter.scale = calcScale(size: image.extent.size)
        return filter.outputImage?.cropped(to: image.extent) ?? image
    }

    override func executeMetalPetal(_ image: MTIImage?, _: VideoEffectInfo) -> MTIImage? {
        guard let image else {
            return image
        }
        let filter = MTIPixellateFilter()
        filter.inputImage = image
        let scale = CGFloat(calcScale(size: image.extent.size))
        filter.scale = .init(width: scale, height: scale)
        return filter.outputImage
    }

    private func calcScale(size: CGSize) -> Float {
        let maximum = Float(size.maximum())
        let sizeInPixels = 20 * (maximum / 1920) * (1 + 5 * strength.value)
        return maximum / Float(Int(maximum / sizeInPixels))
    }
}
