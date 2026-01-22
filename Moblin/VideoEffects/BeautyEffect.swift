import MetalPetal

final class BeautyEffect: VideoEffect {
    private var amount: Float = 0.65
    private var radius: Float = 20.0

    func setSettings(amount: Float, radius: Float) {
        processorPipelineQueue.async {
            self.amount = amount
            self.radius = radius
        }
    }

    override func executeMetalPetal(_ image: MTIImage, _: VideoEffectInfo) -> MTIImage {
        let filter = MTIHighPassSkinSmoothingFilter()
        filter.amount = amount
        filter.radius = radius
        filter.inputImage = image
        return filter.outputImage ?? image
    }

    override func isMetalPetal() -> Bool {
        return true
    }
}
