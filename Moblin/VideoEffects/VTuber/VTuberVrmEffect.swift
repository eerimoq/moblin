import SceneKit
import SwiftUI
@preconcurrency import VRMSceneKit

final class VTuberVrmEffect: VTuberEffect, @unchecked Sendable {
    private var scene: VRMScene?
    private var armsAngle: Double = .pi / 2.5
    private let renderer = SCNRenderer(device: nil)
    private var cameraNode: SCNNode?

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

    override func setModelSettings(cameraFieldOfView: Double, cameraPositionY: Double, armsAngle: Double) {
        cameraNode?.camera?.fieldOfView = cameraFieldOfView
        cameraNode?.position = SCNVector3(0, cameraPositionY, -1.8)
        self.armsAngle = armsAngle.toRadians()
    }

    override func isModelLoaded() -> Bool {
        scene != nil
    }

    override func updateModel(face: VTuberFace, time: Double, timeDelta _: Double) {
        guard let node = scene?.vrmNode else {
            return
        }
        node.setBlendShape(value: face.mouthOpen, for: .preset(.a))
        node.setBlendShape(value: 1 - face.leftEyeOpen, for: .preset(.blink))
        let neckYAngle = face.sideAngle * 0.8
        let neckZAngle = face.rotationAngle * 0.8
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

    override func renderModel(time: Double, size: CGSize) -> EffectImage? {
        guard let node = scene?.vrmNode else {
            return nil
        }
        node.update(at: time)
        let factor = (max(size.width, size.height) / 1920)
        let vTuberImage = renderer.snapshot(atTime: time,
                                            with: CGSize(width: 600 * factor, height: 600 * factor),
                                            antialiasingMode: .none)
        return vTuberImage.cgImage?.toEffectImage()
    }
}
