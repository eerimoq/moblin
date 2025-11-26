import CoreImage

final class PinchEffect: VideoEffect {
    private var scale: Float

    init(scale: Float) {
        self.scale = scale
    }

    func setSettings(scale: Float) {
        processorPipelineQueue.async {
            self.scale = scale
        }
    }

    override func getName() -> String {
        return "Pinch"
    }

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        let filter = CIFilter.pinchDistortion()
        filter.inputImage = image
        filter.radius = Float(min(image.extent.width, image.extent.height) / 2)
        filter.scale = scale
        filter.center = CGPoint(x: image.extent.width / 2, y: image.extent.height / 2)
        return filter.outputImage?.cropped(to: image.extent) ?? image
    }
}
