import CoreImage

func pixellateCalcScale(size: CGSize, strength: Float) -> Float {
    let maximum = Float(size.maximum())
    let sizeInPixels = 20 * (maximum / 1920) * (1 + 5 * strength)
    return maximum / Float(Int(maximum / sizeInPixels))
}

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

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        filter.inputImage = image
        filter.center = .zero
        filter.scale = pixellateCalcScale(size: image.extent.size, strength: strength)
        return filter.outputImage?.cropped(to: image.extent) ?? image
    }
}
