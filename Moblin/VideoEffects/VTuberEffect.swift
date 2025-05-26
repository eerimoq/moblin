import SceneKit
import UIKit
import VRMSceneKit

final class VTuberEffect: VideoEffect {
    private let scene: VRMScene?
    private let renderer = SCNRenderer(device: nil)
    private var firstPresentationTimeStamp: Double?

    init(vrm: URL) {
        do {
            scene = try VRMSceneLoader(withURL: vrm).loadScene()
        } catch {
            logger.info("v-tuber: Failed to load VRM file with error: \(error)")
            scene = nil
        }
        guard let scene else {
            return
        }
        let camera = SCNCamera()
        camera.fieldOfView = 18
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 1.37, -1.8)
        cameraNode.rotation = SCNVector4(0, 1, 0, Float.pi)
        scene.rootNode.addChildNode(cameraNode)
        renderer.scene = scene
        let node = scene.vrmNode
        node.humanoid.node(for: .leftShoulder)?.eulerAngles = SCNVector3(0, 0, 40 * CGFloat.pi / 180)
        node.humanoid.node(for: .rightShoulder)?.eulerAngles = SCNVector3(0, 0, -40 * CGFloat.pi / 180)
    }

    override func getName() -> String {
        return "VTuber"
    }

    override func execute(_ image: CIImage, _ info: VideoEffectInfo) -> CIImage {
        let presentationTimeStamp = info.presentationTimeStamp.seconds
        if firstPresentationTimeStamp == nil {
            firstPresentationTimeStamp = presentationTimeStamp
        }
        guard let scene, let firstPresentationTimeStamp else {
            return image
        }
        let node = scene.vrmNode
        if let detection = info.faceDetections[info.sceneVideoSourceId]?.first {
            node.setBlendShape(value: detection.isMouthOpen(), for: .preset(.angry))
            node.setBlendShape(value: -(detection.isLeftEyeOpen() - 1), for: .preset(.blink))
        } else {
            node.setBlendShape(value: 0, for: .preset(.angry))
            node.setBlendShape(value: 0, for: .preset(.blink))
        }
        let time = presentationTimeStamp - firstPresentationTimeStamp
        var angle = time.remainder(dividingBy: .pi * 2)
        if angle < 0 {
            angle *= -1
        }
        angle -= .pi / 2
        angle *= 0.5
        let armAngle = (angle * 0.05) + .pi / 5
        node.humanoid.node(for: .leftShoulder)?.eulerAngles = SCNVector3(0, 0, armAngle)
        node.humanoid.node(for: .rightShoulder)?.eulerAngles = SCNVector3(0, 0, -armAngle)
        node.humanoid.node(for: .neck)?.eulerAngles = SCNVector3(0, 0, angle * 0.05)
        node.update(at: time)
        let width = 300.0
        let height = 400.0
        let vTuberImage = renderer.snapshot(atTime: time,
                                            with: CGSize(width: width, height: height),
                                            antialiasingMode: .multisampling4X)
        return CIImage(image: vTuberImage)?
            .transformed(by: CGAffineTransform(translationX: image.extent.width - width, y: 0))
            .composited(over: image) ?? image
    }

    override func needsFaceDetections(_: Double) -> (Bool, UUID?) {
        return (true, nil)
    }
}
