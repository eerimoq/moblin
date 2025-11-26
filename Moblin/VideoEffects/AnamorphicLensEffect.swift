import UIKit

final class AnamorphicLensEffect: VideoEffect {
    private var settings: SettingsVideoEffectAnamorphicLens

    init(settings: SettingsVideoEffectAnamorphicLens) {
        self.settings = settings
    }

    func setSettings(settings: SettingsVideoEffectAnamorphicLens) {
        processorPipelineQueue.async {
            self.settings = settings
        }
    }

    override func getName() -> String {
        return "Anamorphic lens"
    }

    override func executeEarly(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        let filter = CIFilter.stretchCrop()
        filter.inputImage = image
        filter.centerStretchAmount = 1
        filter.size = CGPoint(x: image.extent.width * settings.scale, y: image.extent.height)
        return filter.outputImage ?? image
    }
}
