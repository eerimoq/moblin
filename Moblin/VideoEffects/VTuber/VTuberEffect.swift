import CoreImage
import MetalPetal
import Vision

struct VTuberFace {
    var sideAngle = 0.0
    var rotationAngle = 0.0
    var mouthOpen = 0.0
    var leftEyeOpen = 1.0
    var rightEyeOpen = 1.0
}

class VTuberEffect: VideoEffect, @unchecked Sendable {
    private var videoSourceId: UUID = .init()
    private var mirror: Bool = false
    private var sensitivity = SettingsSensitivity()
    private var sceneWidget: SettingsSceneWidget?
    private var timeStampRebaser = TimeStampRebaser()
    private var previousPresentationTimeStamp = 0.0
    private var face = VTuberFace()
    private var latestSideAngle = 0.0
    private var latestRotationAngle = 0.0
    private var renderedImagePresentationTimeStamp = 0.0
    private var renderedImage: EffectImage?

    func setVideoSourceId(videoSourceId: UUID) {
        processorPipelineQueue.async {
            self.videoSourceId = videoSourceId
        }
    }

    func setSettings(cameraFieldOfView: Double,
                     cameraPositionY: Double,
                     mirror: Bool,
                     sensitivity: SettingsSensitivity,
                     armsAngle: Double)
    {
        processorPipelineQueue.async {
            self.mirror = mirror
            self.sensitivity = sensitivity
            self.setModelSettings(cameraFieldOfView: cameraFieldOfView,
                                  cameraPositionY: cameraPositionY,
                                  armsAngle: armsAngle)
        }
    }

    func setSceneWidget(sceneWidget: SettingsSceneWidget) {
        processorPipelineQueue.async {
            self.sceneWidget = sceneWidget
        }
    }

    func setModelSettings(cameraFieldOfView _: Double, cameraPositionY _: Double, armsAngle _: Double) {}

    func isModelLoaded() -> Bool {
        false
    }

    func updateModel(face _: VTuberFace, time _: Double, timeDelta _: Double) {}

    func renderModel(time _: Double, size _: CGSize) -> EffectImage? {
        nil
    }

    override func execute(_ image: CIImage, _ info: VideoEffectInfo) -> CIImage {
        guard let renderedImage = update(size: image.extent.size, info: info)?.getCiImage(),
              let sceneWidget
        else {
            return image
        }
        return renderedImage
            .resizeMirror(sceneWidget.layout, image.extent.size, mirror)
            .move(sceneWidget.layout, image.extent.size)
            .cropped(to: image.extent)
            .composited(over: image)
    }

    override func executeMetalPetal(_ image: MTIImage, _ info: VideoEffectInfo) -> MTIImage {
        guard let renderedImage = update(size: image.extent.size, info: info)?.getMetalPetalImage(),
              let sceneWidget
        else {
            return image
        }
        return renderedImage.resizeMirrorMoveComposited(sceneWidget.layout,
                                                        mirror,
                                                        image,
                                                        .init(contentRegion: renderedImage.extent))
    }

    private func update(size: CGSize, info: VideoEffectInfo) -> EffectImage? {
        let presentationTimeStamp = info.presentationTimeStamp.seconds
        guard let time = timeStampRebaser.rebase(presentationTimeStamp), isModelLoaded() else {
            return nil
        }
        let timeDelta = presentationTimeStamp - previousPresentationTimeStamp
        previousPresentationTimeStamp = presentationTimeStamp
        updateFace(size: size, info: info, timeDelta: timeDelta)
        updateModel(face: face, time: time, timeDelta: timeDelta)
        if presentationTimeStamp - renderedImagePresentationTimeStamp > 0.025,
           let image = renderModel(time: time, size: size)
        {
            renderedImage = image
            renderedImagePresentationTimeStamp = presentationTimeStamp
        }
        return renderedImage
    }

    private func updateFace(size: CGSize, info: VideoEffectInfo, timeDelta: Double) {
        if let detection = info.faceDetections(videoSourceId)?.first,
           let rotationAngle = detection.calcFaceAngle(imageSize: size),
           let sideAngle = detection.calcFaceAngleSide()
        {
            face.mouthOpen = detection.isMouthOpen(
                rotationAngle: rotationAngle,
                sensitivity: sensitivity.mouth
            )
            face.leftEyeOpen = detection.isLeftEyeOpen(rotationAngle: rotationAngle,
                                                       sensitivity: sensitivity.eyes)
            face.rightEyeOpen = detection.isRightEyeOpen(rotationAngle: rotationAngle,
                                                         sensitivity: sensitivity.eyes)
            latestSideAngle = sideAngle
            latestRotationAngle = rotationAngle
        }
        let newFactor = min(0.1 * (timeDelta / 0.033), 0.5)
        let oldFactor = 1 - newFactor
        face.sideAngle = oldFactor * face.sideAngle + newFactor * latestSideAngle
        face.rotationAngle = oldFactor * face.rotationAngle + newFactor * latestRotationAngle
    }

    override func needsFaceDetections(_: Double) -> VideoEffectDetectionsMode {
        .interval(videoSourceId, 0.1)
    }
}
