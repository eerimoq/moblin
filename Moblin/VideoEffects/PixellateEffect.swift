import AVFoundation
import UIKit
import Vision

final class PixellateEffect: VideoEffect {
    private let filter = CIFilter.pixellate()
    private var strength: Float

    init(strength: Float) {
        self.strength = .init(strength)
    }

    func setSettings(strength: Float) {
        processorPipelineQueue.async {
            self.strength = strength
        }
    }

    override func getName() -> String {
        return "Pixellate filter"
    }

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        filter.inputImage = image
        filter.center = .init(x: 0, y: 0)
        filter.scale = calcScale(size: image.extent.size)
        return filter.outputImage?.cropped(to: image.extent) ?? image
    }

    private func calcScale(size: CGSize) -> Float {
        let maximum = Float(size.maximum())
        let sizeInPixels = 20 * (maximum / 1920) * (1 + 5 * strength)
        return maximum / Float(Int(maximum / sizeInPixels))
    }
}
