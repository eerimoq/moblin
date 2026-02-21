import CoreImage

final class OpacityEffect: VideoEffect {
    private var opacity: Double = 1.0

    func setOpacity(opacity: Double) {
        processorPipelineQueue.async {
            self.opacity = opacity
        }
    }

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        let filter = CIFilter.colorMatrix()
        filter.aVector = .init(x: 0, y: 0, z: 0, w: opacity)
        filter.inputImage = image
        return filter.outputImage ?? image
    }
}
