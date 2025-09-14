import CoreImage

struct Dewarp360EffectSettings {
    var fieldOfView: Float = .pi / 2
    var xAngle: Float = 0
    var yAngle: Float = 0
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
        filter.outputSize = CGSize(width: 1920, height: 1080)
        filter.fieldOfView = settings.fieldOfView
        filter.xAngle = settings.xAngle
        filter.yAngle = settings.yAngle
        return filter.outputImage ?? image
    }
}
