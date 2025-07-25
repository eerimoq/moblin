import AVFoundation
import CoreImage.CIFilterBuiltins
import MetalPetal
import Vision

public struct VideoEffectInfo {
    let isFirstAfterAttach: Bool
    let sceneVideoSourceId: UUID
    let faceDetectionJobs: [FaceDetectionJob]
    let faceDetections: [UUID: [VNFaceObservation]]
    // periphery:ignore
    let presentationTimeStamp: CMTime
    // periphery:ignore
    let videoUnit: VideoUnit

    func sceneFaceDetections() -> [VNFaceObservation]? {
        return faceDetections[sceneVideoSourceId]
    }

    func getCiImage(_ videoSourceId: UUID) -> CIImage? {
        guard let imageBuffer = faceDetectionJobs.first(where: { $0.videoSourceId == videoSourceId })?.imageBuffer
        else {
            return videoUnit.getCiImage(videoSourceId, presentationTimeStamp)
        }
        return CIImage(cvPixelBuffer: imageBuffer)
    }
}

open class VideoEffect: NSObject {
    var effects: [VideoEffect] = []

    open func getName() -> String {
        return ""
    }

    open func needsFaceDetections(_: Double) -> (Bool, UUID?, Double?) {
        return (false, nil, nil)
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

    func applyEffects(_ image: CIImage, _ info: VideoEffectInfo) -> CIImage {
        var image = image
        for effect in effects {
            image = effect.execute(image, info)
        }
        return image
    }
}
