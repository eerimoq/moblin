import AVFoundation
import UIKit
import Vision

final class MovieEffect: VideoEffect {
    override func getName() -> String {
        return "Movie filter"
    }

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        return image
            .cropped(to: CGRect(x: 0,
                                y: image.extent.height / 6,
                                width: image.extent.width,
                                height: 2 * image.extent.height / 3))
            .composited(over: CIImage.black.cropped(to: image.extent))
    }
}
