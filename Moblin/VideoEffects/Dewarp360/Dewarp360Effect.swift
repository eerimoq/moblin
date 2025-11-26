import AVFoundation
import CoreImage

enum Dewarp360EffectSettings {
    case direct(pan: Float = 0, tilt: Float = 0, fieldOfView: Float = .pi / 2)
    case animate(speed: Float = 1, pan: Float = 0, tilt: Float = 0, fieldOfView: Float = .pi / 2)
}

final class Dewarp360Effect: VideoEffect {
    private let filter = Dewarp360Filter()
    private var settings: Dewarp360EffectSettings = .direct()
    private var currentPan: Float = 0
    private var currentTilt: Float = 0
    private var currentFieldOfView: Float = .pi / 2
    private var currentSpeed: Float = 0
    private var latestPresentationTimeStamp: CMTime?

    override func getName() -> String {
        return "Dewarp 360 filter"
    }

    func setSettings(settings: Dewarp360EffectSettings) {
        processorPipelineQueue.async {
            self.applySettings(settings: settings)
        }
    }

    override func executeEarly(_ image: CIImage, _ info: VideoEffectInfo) -> CIImage {
        updateParameters(info: info)
        filter.inputImage = image
        filter.outputSize = info.videoUnit.canvasSize
        filter.pan = currentPan
        filter.tilt = currentTilt
        filter.fieldOfView = currentFieldOfView
        return filter.outputImage ?? image
    }

    private func applySettings(settings: Dewarp360EffectSettings) {
        self.settings = settings
        switch settings {
        case let .direct(pan, tilt, fieldOfView):
            currentPan = pan
            currentTilt = tilt
            currentFieldOfView = fieldOfView
        case .animate:
            break
        }
    }

    private func updateParameters(info: VideoEffectInfo) {
        switch settings {
        case .direct:
            break
        case let .animate(_, pan, tilt, fieldOfView):
            // Need some kind of physics model of the movement.
            currentPan = pan
            currentTilt = tilt
            currentFieldOfView = fieldOfView
        }
        latestPresentationTimeStamp = info.presentationTimeStamp
    }

    private func calcElapsedTime(presentationTimeStamp: CMTime) -> Float {
        return Float((presentationTimeStamp - (latestPresentationTimeStamp ?? presentationTimeStamp)).seconds)
    }
}
