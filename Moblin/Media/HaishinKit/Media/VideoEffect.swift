import AVFoundation
import CoreImage.CIFilterBuiltins
import MetalPetal
import Vision

public struct VideoEffectInfo {
    let isFirstAfterAttach: Bool
    let faceDetections: [VNFaceObservation]?
    // periphery:ignore
    let presentationTimeStamp: CMTime
    // periphery:ignore
    let videoUnit: VideoUnit
}

open class VideoEffect: NSObject {
    open func getName() -> String {
        return ""
    }

    open func needsFaceDetections() -> Bool {
        return false
    }

    open func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        return image
    }

    open func executeMetalPetal(_ image: MTIImage?, _: VideoEffectInfo) -> MTIImage? {
        return image
    }

    open func removed() {}

    open func shouldRemove() -> Bool {
        return false
    }
}
