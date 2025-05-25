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
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        scene.rootNode.addChildNode(cameraNode)
        cameraNode.position = SCNVector3(0, 0.8, -1.8)
        cameraNode.rotation = SCNVector4(0, 1, 0, Float.pi)
        renderer.scene = scene
        let node = scene.vrmNode
        node.runAction(.repeatForever(.sequence([
            .rotateBy(x: 0, y: -0.5, z: 0, duration: 0.5),
            .rotateBy(x: 0, y: 0.5, z: 0, duration: 0.5),
        ])))
    }

    override func getName() -> String {
        return "VTuber"
    }

    private func calcMinXMaxYWidthHeight(points: [CGPoint]) -> (CGFloat, CGFloat, CGFloat, CGFloat)? {
        guard let firstPoint = points.first else {
            return nil
        }
        var minX = firstPoint.x
        var maxX = firstPoint.x
        var minY = firstPoint.y
        var maxY = firstPoint.y
        for point in points {
            minX = min(point.x, minX)
            maxX = max(point.x, maxX)
            minY = min(point.y, minY)
            maxY = max(point.y, maxY)
        }
        let width = maxX - minX
        let height = maxY - minY
        return (minX, maxY, width, height)
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
        let node = scene.vrmNode
        var angle = time.remainder(dividingBy: .pi * 2)
        if angle < 0 {
            angle *= -1
        }
        angle -= .pi / 2
        angle *= 0.5
        if let detection = info.faceDetections[info.sceneVideoSourceId]?.first {
            if let innerLips = detection.landmarks?.innerLips {
                let points = innerLips.normalizedPoints
                if let (_, _, _, height) = calcMinXMaxYWidthHeight(points: points) {
                    node.setBlendShape(value: min(height * 6, 1), for: .preset(.angry))
                }
            }
        }
        if let detection = info.faceDetections[info.sceneVideoSourceId]?.first {
            if let leftEye = detection.landmarks?.leftEye {
                let points = leftEye.normalizedPoints
                if let (_, _, _, height) = calcMinXMaxYWidthHeight(points: points) {
                    node.setBlendShape(value: height > 0.035 ? 0 : 1, for: .preset(.blink))
                }
            }
        }
        node.humanoid.node(for: .leftShoulder)?.eulerAngles = SCNVector3(0, 0, angle)
        node.humanoid.node(for: .rightShoulder)?.eulerAngles = SCNVector3(0, 0, angle)
        node.humanoid.node(for: .neck)?.eulerAngles = SCNVector3(0, 0, angle * 0.7)
        node.update(at: time)
        let vTuberImage = renderer.snapshot(atTime: time,
                                            with: CGSize(width: 300, height: 600),
                                            antialiasingMode: .multisampling4X)
        return CIImage(image: vTuberImage)?
            .transformed(by: CGAffineTransform(translationX: image.extent.width - 300, y: -40))
            .cropped(to: image.extent)
            .composited(over: image) ?? image
    }

    override func needsFaceDetections(_: Double) -> (Bool, UUID?) {
        return (true, nil)
    }
}
