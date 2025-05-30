import UIKit

final class WhirlpoolEffect: VideoEffect {
    private var angle: Float

    init(angle: Float) {
        self.angle = angle
    }

    func setSettings(angle: Float) {
        mixerLockQueue.async {
            self.angle = angle
        }
    }

    override func getName() -> String {
        return "whirlpool"
    }

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        let filter = CIFilter.twirlDistortion()
        filter.inputImage = image
        filter.angle = angle
        filter.radius = Float(min(image.extent.width, image.extent.height) / 1.9)
        filter.center = CGPoint(x: image.extent.width / 2, y: image.extent.height / 2)
        return filter.outputImage?.cropped(to: image.extent) ?? image
    }
}
