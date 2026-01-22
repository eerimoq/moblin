import AVFoundation
import UIKit
import Vision

final class FourThreeEffect: VideoEffect {
    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        return image
            .cropped(to: CGRect(x: image.extent.width / 8,
                                y: 0,
                                width: 3 * image.extent.width / 4,
                                height: image.extent.height))
            .composited(over: CIImage.black.cropped(to: image.extent))
    }
}
