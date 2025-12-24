import AVFoundation
import CoreImage.CIFilterBuiltins
import Vision

public struct VideoEffectInfo {
    let isFirstAfterAttach: Bool
    let sceneVideoSourceId: UUID
    let faceDetectionJobs: [FaceDetectionJob]
    let faceDetections: [UUID: [VNFaceObservation]]
    let presentationTimeStamp: CMTime
    let videoUnit: VideoUnit

    func sceneFaceDetections() -> [VNFaceObservation]? {
        return faceDetections[sceneVideoSourceId]
    }

    func getCiImage(_ videoSourceId: UUID) -> CIImage? {
        guard let imageBuffer = faceDetectionJobs.first(where: { $0.videoSourceId == videoSourceId })?
            .imageBuffer
        else {
            return videoUnit.getCiImage(videoSourceId, presentationTimeStamp)
        }
        return CIImage(cvPixelBuffer: imageBuffer)
    }
}

enum VideoEffectFaceDetectionsMode {
    case off
    case now(UUID?)
    case interval(UUID?, Double)
}

class VideoEffect: NSObject {
    var effects: [VideoEffect] = []

    func getName() -> String {
        return ""
    }

    func needsFaceDetections(_: Double) -> VideoEffectFaceDetectionsMode {
        return .off
    }

    func isEnabled() -> Bool {
        return true
    }

    func executeEarly(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        return image
    }

    func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        return image
    }

    func prepare(_: CIImage, _: VideoEffectInfo) {}

    func removed() {}

    func shouldRemove() -> Bool {
        return false
    }

    func applyEffectsResizeMirrorMove(_ image: CIImage,
                                      _ sceneWidget: SettingsSceneWidget,
                                      _ mirror: Bool,
                                      _ backgroundImageExtent: CGRect,
                                      _ info: VideoEffectInfo) -> CIImage
    {
        let resizedImage = applyEarlyEffects(image, info)
            .resizeMirror(sceneWidget.layout, backgroundImageExtent.size, mirror)
        return applyEffects(resizedImage, info)
            .move(sceneWidget.layout, backgroundImageExtent.size)
            .cropped(to: backgroundImageExtent)
    }

    private func applyEarlyEffects(_ image: CIImage, _ info: VideoEffectInfo) -> CIImage {
        var image = image
        for effect in effects {
            image = effect.executeEarly(image, info)
        }
        return image
    }

    private func applyEffects(_ image: CIImage, _ info: VideoEffectInfo) -> CIImage {
        var image = image
        for effect in effects {
            image = effect.execute(image, info)
        }
        return image
    }
}
