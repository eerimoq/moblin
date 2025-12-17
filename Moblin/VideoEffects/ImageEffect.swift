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
    private var originalImage: CIImage?
    private var sceneWidget: SettingsSceneWidget?
    private let settingName: String
    let widgetId: UUID

    init(imageStorage: ImageStorage, settingName: String, widgetId: UUID) {
        self.settingName = settingName
        self.widgetId = widgetId
        super.init()
        DispatchQueue.global().async {
            guard let data = imageStorage.read(id: widgetId) else {
                return
            }
            guard let image = CIImage(data: data, options: [.applyOrientationProperty: true]) else {
                return
            }
            processorPipelineQueue.async {
                self.originalImage = image
            }
        }
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
