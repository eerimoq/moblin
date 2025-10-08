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

    open func isEarly() -> Bool {
        return false
    }

    func applyEffectsResizeMirrorMove(_ image: CIImage,
                                      _ sceneWidget: SettingsSceneWidget,
                                      _ mirror: Bool,
                                      _ backgroundImageExtent: CGRect,
                                      _ info: VideoEffectInfo) -> CIImage
    {
        let resizedImage = applyEffects(image, info, true)
            .resizeMirror(sceneWidget, backgroundImageExtent.size, mirror)
        return applyEffects(resizedImage, info, false)
            .move(sceneWidget, backgroundImageExtent.size)
            .cropped(to: backgroundImageExtent)
    }

    private func applyEffects(_ image: CIImage, _ info: VideoEffectInfo, _ early: Bool) -> CIImage {
        var image = image
        for effect in effects where effect.isEarly() == early {
            image = effect.execute(image, info)
        }
        return image
    }
}
