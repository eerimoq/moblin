import AVFoundation
import UIKit
import Vision

final class ImageEffect: VideoEffect {
    private let filter = CIFilter.sourceOverCompositing()
    private var originalImage: CIImage?
    private var sceneWidget: SettingsSceneWidget?

    init(imageStorage: ImageStorage, widgetId: UUID) {
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

    override func execute(_ image: CIImage, _ info: VideoEffectInfo) -> CIImage {
        guard let originalImage, let sceneWidget else {
            return image
        }
        filter.inputImage = applyEffectsResizeMirrorMove(
            originalImage,
            sceneWidget,
            false,
            image.extent,
            info
        )
        filter.backgroundImage = image
        return filter.outputImage ?? image
    }
}
