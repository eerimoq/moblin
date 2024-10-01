import AVFoundation
import MetalPetal
import UIKit
import Vision

final class VideoSourceEffect: VideoEffect {
    var x: Float = 0.0
    var y: Float = 0.0
    var width: Float = 0.0
    var height: Float = 0.0
    var videoSourceId: UUID = .init()

    override func getName() -> String {
        return "video source"
    }

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        return image
    }

    override func executeMetalPetal(_ image: MTIImage?, _: VideoEffectInfo) -> MTIImage? {
        return image
    }
}
