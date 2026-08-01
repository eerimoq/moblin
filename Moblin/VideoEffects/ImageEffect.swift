import CoreImage
import MetalPetal

final class ImageEffect: VideoEffect, @unchecked Sendable {
    private let filter = CIFilter.sourceOverCompositing()
    private var originalImage: CIImage?
    private var originalImageMetalPetal: MTIImage?
    private var sceneWidget: SettingsSceneWidget?

    init(imageStorage: ImageStorage, widgetId: UUID) {
        super.init()
        loadImage(imageStorage: imageStorage, widgetId: widgetId)
    }

    func loadImage(imageStorage: ImageStorage, widgetId: UUID) {
        DispatchQueue.global().async {
            guard let data = imageStorage.read(id: widgetId) else {
                return
            }
            guard let image = CIImage(data: data, options: [.applyOrientationProperty: true]) else {
                return
            }
            let imageMetalPetal = MTIImage(ciImage: image)
            processorPipelineQueue.async {
                self.originalImage = image
                self.originalImageMetalPetal = imageMetalPetal
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

    override func executeMetalPetal(_ image: MTIImage, _ info: VideoEffectInfo) -> MTIImage {
        guard let originalImageMetalPetal, let sceneWidget else {
            return image
        }
        return applyEffectsResizeMirrorMoveMetalPetal(originalImageMetalPetal,
                                                      sceneWidget,
                                                      false,
                                                      image,
                                                      info)
    }
}
