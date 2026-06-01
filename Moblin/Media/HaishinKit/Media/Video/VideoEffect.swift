import AVFoundation
import CoreImage.CIFilterBuiltins
import MetalPetal
import Vision

struct VideoEffectInfo {
    let sceneVideoSourceId: UUID
    let detectionJobs: [DetectionJob]
    let detections: [UUID: Detections]
    let presentationTimeStamp: CMTime
    let videoUnit: VideoUnit
    let isFirstAfterAttach: Bool

    func sceneDetections() -> Detections? {
        detections[sceneVideoSourceId]
    }

    func sceneFaceDetections() -> [VNFaceObservation]? {
        detections[sceneVideoSourceId]?.face
    }

    func faceDetections(_ videoSourceId: UUID) -> [VNFaceObservation]? {
        detections[videoSourceId]?.face
    }

    func getCiImage(_ videoSourceId: UUID) -> CIImage? {
        guard let imageBuffer = detectionJobs
            .first(where: { $0.videoSourceId == videoSourceId })?
            .imageBuffer
        else {
            return videoUnit.getCiImage(videoSourceId, presentationTimeStamp)
        }
        return CIImage(cvPixelBuffer: imageBuffer)
    }
}

enum VideoEffectDetectionsMode {
    case off
    case now(UUID?)
    case interval(UUID?, Double)
}

class VideoEffect: NSObject, @unchecked Sendable {
    var effects: [VideoEffect] = []

    func needsFaceDetections(_: Double) -> VideoEffectDetectionsMode {
        .off
    }

    func needsTextDetections(_: Double) -> VideoEffectDetectionsMode {
        .off
    }

    func isEnabled() -> Bool {
        true
    }

    func executeEarly(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        image
    }

    func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        image
    }

    func executeMetalPetal(_ image: MTIImage, _: VideoEffectInfo) -> MTIImage {
        image
    }

    func isMetalPetal() -> Bool {
        false
    }

    func prepare(_: CIImage, _: VideoEffectInfo) {}

    func removed() {}

    func shouldRemove() -> Bool {
        false
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
        return image.cropped(to: image.extent.insetBy(dx: graphicsEpsilon, dy: graphicsEpsilon))
    }
}
