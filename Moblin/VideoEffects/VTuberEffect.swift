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
            let cameraNode = SCNNode()
            cameraNode.camera = SCNCamera()
            scene!.rootNode.addChildNode(cameraNode)
            cameraNode.position = SCNVector3(0, 0.8, -1.8)
            cameraNode.rotation = SCNVector4(0, 1, 0, Float.pi)
            renderer.scene = scene!
            let node = scene!.vrmNode
            // node.setBlendShape(value: 1, for: .preset(.fun))
            node.humanoid.node(for: .neck)?.eulerAngles = SCNVector3(0, 0, 20 * CGFloat.pi / 180)
            node.humanoid.node(for: .leftShoulder)?.eulerAngles = SCNVector3(0, 0, 40 * CGFloat.pi / 180)
            node.humanoid.node(for: .rightShoulder)?.eulerAngles = SCNVector3(0, 0, 40 * CGFloat.pi / 180)
            // node.runAction(SCNAction.rotateBy(x: -0.5, y: 0, z: 0, duration: 1.0))
            node.runAction(.repeatForever(.sequence([
                SCNAction.rotateBy(x: 0, y: -0.5, z: 0, duration: 0.5),
                SCNAction.rotateBy(x: 0, y: 0.5, z: 0, duration: 0.5),
            ])))
        } catch {
            logger.info("v-tuber: Failed to load VRM file with error: \(error)")
            scene = nil
        }
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
        let time = presentationTimeStamp - firstPresentationTimeStamp
        scene.vrmNode.update(at: time)
        let vTuberImage = renderer.snapshot(atTime: time,
                                            with: CGSize(width: 300, height: 600),
                                            antialiasingMode: .multisampling4X)
        return CIImage(image: vTuberImage)?
            .transformed(by: CGAffineTransform(translationX: image.extent.width - 300, y: -40))
            .cropped(to: image.extent)
            .composited(over: image) ?? image
    }
}
