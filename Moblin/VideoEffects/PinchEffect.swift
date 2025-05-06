import UIKit

final class PinchEffect: VideoEffect {
    override func getName() -> String {
        return "pinch"
    }

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        let filter = CIFilter.pinchDistortion()
        filter.inputImage = image
        filter.radius = Float(min(image.extent.width, image.extent.height) / 2)
        filter.scale = 0.5
        filter.center = CGPoint(x: image.extent.width / 2, y: image.extent.height / 2)
        return filter.outputImage?.cropped(to: image.extent) ?? image
    }
}
