import MetalPetal
import SceneKit
import SwiftUI
import Vision
@preconcurrency import VRMSceneKit

final class VTuberEffect: VideoEffect, @unchecked Sendable {
    private var videoSourceId: UUID = .init()
    private var scene: VRMScene?
    private var mirror: Bool = false
    private var sensitivity = SettingsSensitivity()
    private var armsAngle: Double = .pi / 2.5
    private let renderer = SCNRenderer(device: nil)
    private var timeStampRebaser = TimeStampRebaser()
    private var previousPresentationTimeStamp = 0.0
    private var neckYAngle = 0.0
    private var neckZAngle = 0.0
    private var latestNeckYAngle = 0.0
    private var latestNeckZAngle = 0.0
    private var cameraNode: SCNNode?
    private var sceneWidget: SettingsSceneWidget?
    private var renderedImagePresentationTimeStamp = 0.0
    private var renderedImage: EffectImageCgImage?

    init(vrm: URL, cameraFieldOfView: Double, cameraPositionY: Double) {
        super.init()
        DispatchQueue.global().async {
            let scene: VRMScene
            do {
                scene = try VRMSceneLoader(withURL: vrm).loadScene()
            } catch {
                logger.info("v-tuber: Failed to load VRM file with error: \(error)")
                return
            }
            processorPipelineQueue.async {
                let camera = SCNCamera()
                camera.fieldOfView = cameraFieldOfView
                let cameraNode = SCNNode()
                cameraNode.camera = camera
                cameraNode.position = SCNVector3(0, cameraPositionY, -1.8)
                cameraNode.rotation = SCNVector4(0, 1, 0, Float.pi)
                scene.rootNode.addChildNode(cameraNode)
                self.renderer.scene = scene
                let node = scene.vrmNode
                node.humanoid.node(for: .leftUpperArm)?.eulerAngles = SCNVector3(0, 0, 40 * CGFloat.pi / 180)
                node.humanoid.node(for: .rightUpperArm)?.eulerAngles = SCNVector3(
                    0,
                    0,
                    -40 * CGFloat.pi / 180
                )
                self.scene = scene
                self.cameraNode = cameraNode
            }
        }
    }

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
            self.cameraNode?.camera?.fieldOfView = cameraFieldOfView
            self.cameraNode?.position = SCNVector3(0, cameraPositionY, -1.8)
            self.mirror = mirror
            self.sensitivity = sensitivity
            self.armsAngle = armsAngle.toRadians()
        }
    }

    func setSceneWidget(sceneWidget: SettingsSceneWidget) {
        processorPipelineQueue.async {
            self.sceneWidget = sceneWidget
        }
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

    private func update(size: CGSize, info: VideoEffectInfo) -> EffectImageCgImage? {
        let presentationTimeStamp = info.presentationTimeStamp.seconds
        guard let time = timeStampRebaser.rebase(presentationTimeStamp), let node = scene?.vrmNode else {
            return nil
        }
        let timeDelta = presentationTimeStamp - previousPresentationTimeStamp
        previousPresentationTimeStamp = presentationTimeStamp
        updateModelPose(node: node, size: size, info: info, time: time, timeDelta: timeDelta)
        renderIfNeeded(node: node, size: size, presentationTimeStamp: presentationTimeStamp, time: time)
        return renderedImage
    }

    private func updateModelPose(node: VRMNode,
                                 size: CGSize,
                                 info: VideoEffectInfo,
                                 time: Double,
                                 timeDelta: Double)
    {
        if let detection = info.faceDetections(videoSourceId)?.first,
           let rotationAngle = detection.calcFaceAngle(imageSize: size),
           let sideAngle = detection.calcFaceAngleSide()
        {
            let isMouthOpen = detection.isMouthOpen(
                rotationAngle: rotationAngle,
                sensitivity: sensitivity.mouth
            )
            node.setBlendShape(value: isMouthOpen, for: .preset(.a))
            let isLeftEyeOpen = -(detection.isLeftEyeOpen(
                rotationAngle: rotationAngle,
                sensitivity: sensitivity.eyes
            ) - 1)
            node.setBlendShape(value: isLeftEyeOpen, for: .preset(.blink))
            latestNeckYAngle = sideAngle * 0.8
            latestNeckZAngle = rotationAngle * 0.8
        }
        let newFactor = min(0.1 * (timeDelta / 0.033), 0.5)
        let oldFactor = 1 - newFactor
        neckYAngle = oldFactor * neckYAngle + newFactor * latestNeckYAngle
        neckZAngle = oldFactor * neckZAngle + newFactor * latestNeckZAngle
        node.humanoid.node(for: .neck)?.eulerAngles = SCNVector3(0, -neckYAngle, -neckZAngle)
        node.humanoid.node(for: .spine)?.eulerAngles = SCNVector3(0, -neckYAngle / 3, -neckZAngle / 3)
        var angle = time.remainder(dividingBy: .pi * 2)
        if angle < 0 {
            angle *= -1
        }
        angle -= .pi / 2
        angle *= 0.5
        let armAngle = (angle * 0.1) + armsAngle
        node.humanoid.node(for: .leftUpperArm)?.eulerAngles = SCNVector3(0, 0, armAngle)
        node.humanoid.node(for: .rightUpperArm)?.eulerAngles = SCNVector3(0, 0, -armAngle)
    }

    private func renderIfNeeded(node: VRMNode, size: CGSize, presentationTimeStamp: Double, time: Double) {
        guard presentationTimeStamp - renderedImagePresentationTimeStamp > 0.025 else {
            return
        }
        node.update(at: time)
        let factor = (max(size.width, size.height) / 1920)
        let width = 600.0 * factor
        let height = 600.0 * factor
        let vTuberImage = renderer.snapshot(atTime: time,
                                            with: CGSize(width: width, height: height),
                                            antialiasingMode: .none)
        if let vTuberImage = vTuberImage.cgImage {
            renderedImage = vTuberImage.toEffectImage()
            renderedImagePresentationTimeStamp = presentationTimeStamp
        }
    }

    override func needsFaceDetections(_: Double) -> VideoEffectDetectionsMode {
        .interval(videoSourceId, 0.1)
    }
}
