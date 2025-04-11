import AVFoundation
import CoreImage.CIFilterBuiltins
import MetalPetal
import Vision

public struct VideoEffectInfo {
    let isFirstAfterAttach: Bool
    let sceneVideoSourceId: UUID
    let faceDetections: [UUID: [VNFaceObservation]]
    // periphery:ignore
    let presentationTimeStamp: CMTime
    // periphery:ignore
    let videoUnit: VideoUnit

    func sceneFaceDetections() -> [VNFaceObservation]? {
        return faceDetections[sceneVideoSourceId]
    }
}

open class VideoEffect: NSObject {
    open func getName() -> String {
        return ""
    }

    open func needsFaceDetections() -> (Bool, UUID?) {
        return (false, nil)
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
