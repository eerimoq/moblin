import CoreImage

struct Dewarp360EffectSettings {
    var fov: Float = .pi / 2
    var phi: Float = 0
    var theta: Float = 0
}

final class Dewarp360Effect: VideoEffect {
    private let filter = Dewarp360Filter()
    private var settings: Dewarp360EffectSettings = .init()

    override func getName() -> String {
        return "dewarp 360 filter"
    }

    func setSettings(settings: Dewarp360EffectSettings) {
        processorPipelineQueue.async {
            self.settings = settings
        }
    }

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        filter.inputImage = image
        filter.fov = settings.fov
        filter.phi = settings.phi
        filter.theta = settings.theta
        return filter.outputImage ?? image
    }
}
