import AVFoundation
import UIKit
import Vision

extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up:
            self = .up
        case .upMirrored:
            self = .upMirrored
        case .down:
            self = .down
        case .downMirrored:
            self = .downMirrored
        case .left:
            self = .left
        case .leftMirrored:
            self = .leftMirrored
        case .right:
            self = .right
        case .rightMirrored:
            self = .rightMirrored
        @unknown default:
            self = .up
        }
    }
}

final class ImageEffect: VideoEffect {
    private let filter = CIFilter.sourceOverCompositing()
    private let originalImage: CIImage?
    private var sceneWidget: SettingsSceneWidget?
    private let settingName: String
    let widgetId: UUID

    init(image: CIImage, settingName: String, widgetId: UUID) {
        originalImage = image
        self.settingName = settingName
        self.widgetId = widgetId
        super.init()
    }

    func setSceneWidget(sceneWidget: SettingsSceneWidget) {
        processorPipelineQueue.async {
            self.sceneWidget = sceneWidget
        }
    }

    override func getName() -> String {
        return "\(settingName) image widget"
    }

    override func execute(_ image: CIImage, _ info: VideoEffectInfo) -> CIImage {
        guard let originalImage, let sceneWidget else {
            return image
        }
        filter.inputImage = applyEffectsResizeMirrorMove(originalImage, sceneWidget, false, image.extent, info)
        filter.backgroundImage = image
        return filter.outputImage ?? image
    }
}
