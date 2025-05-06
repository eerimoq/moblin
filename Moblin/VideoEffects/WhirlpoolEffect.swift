import UIKit

final class WhirlpoolEffect: VideoEffect {

    override func getName() -> String {
        return "whirlpool"
    }

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        let filter = CIFilter.twirlDistortion()
        filter.inputImage = image
        filter.angle = .pi / 2
        filter.radius = Float(min(image.extent.width, image.extent.height) / 1.9)
        filter.center = CGPoint(x: image.extent.width / 2, y: image.extent.height / 2)
        return filter.outputImage?.cropped(to: image.extent) ?? image
    }
}
