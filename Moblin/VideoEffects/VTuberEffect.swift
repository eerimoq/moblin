import SceneKit
import UIKit
import Vision
import VRMSceneKit

final class VTuberEffect: VideoEffect {
    private var videoSourceId: UUID = .init()
    private var scene: VRMScene?
    private let renderer = SCNRenderer(device: nil)
    private var firstPresentationTimeStamp: Double?
    private var previousPresentationTimeStamp = 0.0
    private var neckYAngle = 0.0
    private var neckZAngle = 0.0
    private var latestNeckYAngle = 0.0
    private var latestNeckZAngle = 0.0
    private var cameraNode: SCNNode?
    private var sceneWidget: SettingsSceneWidget?
    private var needsDetectionsPresentationTimeStamp = 0.0
    private var renderedImagePresentationTimeStamp = 0.0
    private var renderedImage: CIImage?

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
            mixerLockQueue.async {
                let camera = SCNCamera()
                camera.fieldOfView = cameraFieldOfView
                let cameraNode = SCNNode()
                cameraNode.camera = camera
                cameraNode.position = SCNVector3(0, cameraPositionY, -1.8)
                cameraNode.rotation = SCNVector4(0, 1, 0, Float.pi)
                scene.rootNode.addChildNode(cameraNode)
                self.renderer.scene = scene
                let node = scene.vrmNode
                node.humanoid.node(for: .leftShoulder)?.eulerAngles = SCNVector3(0, 0, 40 * CGFloat.pi / 180)
                node.humanoid.node(for: .rightShoulder)?.eulerAngles = SCNVector3(0, 0, -40 * CGFloat.pi / 180)
                self.scene = scene
                self.cameraNode = cameraNode
            }
        }
    }

    func setVideoSourceId(videoSourceId: UUID) {
        mixerLockQueue.async {
            self.videoSourceId = videoSourceId
        }
    }

    func setCameraSettings(cameraFieldOfView: Double, cameraPositionY: Double) {
        mixerLockQueue.async {
            self.cameraNode?.camera?.fieldOfView = cameraFieldOfView
            self.cameraNode?.position = SCNVector3(0, cameraPositionY, -1.8)
        }
    }

    func setSceneWidget(sceneWidget: SettingsSceneWidget) {
        mixerLockQueue.async {
            self.sceneWidget = sceneWidget
        }
    }

    override func getName() -> String {
        return "VTuber"
    }

    private func makeTranslation(_ vTuberImage: CIImage,
                                 _ sceneWidget: SettingsSceneWidget,
                                 _ size: CGSize) -> CGAffineTransform
    {
        let x = toPixels(sceneWidget.x, size.width)
        let y = size.height - toPixels(sceneWidget.y, size.height) - vTuberImage.extent.height
        return CGAffineTransform(translationX: x, y: y)
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
        let timeDelta = presentationTimeStamp - previousPresentationTimeStamp
        previousPresentationTimeStamp = presentationTimeStamp
        let node = scene.vrmNode
        updateModelPose(node: node, image: image, info: info, time: time, timeDelta: timeDelta)
        renderIfNeeded(node: node, image: image, presentationTimeStamp: presentationTimeStamp, time: time)
        guard var renderedImage, let sceneWidget else {
            return image
        }
        renderedImage = renderedImage
            .transformed(by: CGAffineTransform(scaleX: 0.75, y: 0.75))
        return renderedImage
            .transformed(by: makeTranslation(renderedImage, sceneWidget, image.extent.size))
            .cropped(to: image.extent)
            .composited(over: image)
    }

    private func updateModelPose(node: VRMNode,
                                 image: CIImage,
                                 info: VideoEffectInfo,
                                 time: Double,
                                 timeDelta: Double)
    {
        if let detection = info.faceDetections[videoSourceId]?.first,
           let rotationAngle = detection.calcFaceAngle(imageSize: image.extent.size),
           let sideAngle = detection.calcFaceAngleSide()
        {
            let isMouthOpen = detection.isMouthOpen(rotationAngle: rotationAngle)
            node.setBlendShape(value: isMouthOpen, for: .preset(.a))
            let isLeftEyeOpen = -(detection.isLeftEyeOpen(rotationAngle: rotationAngle) - 1)
            node.setBlendShape(value: isLeftEyeOpen, for: .preset(.blink))
            latestNeckYAngle = sideAngle * 0.8
            latestNeckZAngle = rotationAngle * 0.8
        }
        let newFactor = min(0.15 * (timeDelta / 0.033), 0.5)
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
        let armAngle = (angle * 0.1) + .pi / 3.5
        node.humanoid.node(for: .leftShoulder)?.eulerAngles = SCNVector3(0, 0, armAngle)
        node.humanoid.node(for: .rightShoulder)?.eulerAngles = SCNVector3(0, 0, -armAngle)
    }

    private func renderIfNeeded(node: VRMNode, image: CIImage, presentationTimeStamp: Double, time: Double) {
        guard presentationTimeStamp - renderedImagePresentationTimeStamp > 0.025 else {
            return
        }
        node.update(at: time)
        let factor = (max(image.extent.width, image.extent.height) / 1920)
        let width = 600.0 * factor
        let height = 600.0 * factor
        let vTuberImage = renderer.snapshot(atTime: time,
                                            with: CGSize(width: width, height: height),
                                            antialiasingMode: .none)
        if let vTuberImage = CIImage(image: vTuberImage) {
            renderedImage = vTuberImage
            renderedImagePresentationTimeStamp = presentationTimeStamp
        }
    }

    override func needsFaceDetections(_: Double) -> (Bool, UUID?, Double?) {
        return (false, videoSourceId, 0.1)
    }

    private func createMesh(landmark: VNFaceLandmarkRegion2D?, image: CIImage?) -> [CIVector] {
        guard let landmark, let image else {
            return []
        }
        var mesh: [CIVector] = []
        let points = landmark.pointsInImage(imageSize: image.extent.size)
        switch landmark.pointsClassification {
        case .closedPath:
            for i in 0 ..< landmark.pointCount {
                let j = (i + 1) % landmark.pointCount
                mesh.append(CIVector(x: points[i].x,
                                     y: points[i].y,
                                     z: points[j].x,
                                     w: points[j].y))
            }
        case .openPath:
            for i in 0 ..< landmark.pointCount - 1 {
                mesh.append(CIVector(x: points[i].x,
                                     y: points[i].y,
                                     z: points[i + 1].x,
                                     w: points[i + 1].y))
            }
        case .disconnected:
            for i in 0 ..< landmark.pointCount - 1 {
                mesh.append(CIVector(x: points[i].x,
                                     y: points[i].y,
                                     z: points[i + 1].x,
                                     w: points[i + 1].y))
            }
        }
        return mesh
    }

    private func addFaceLandmarks(image: CIImage?, detections: [VNFaceObservation]?) -> CIImage? {
        guard let image, let detections else {
            return image
        }
        var mesh: [CIVector] = []
        for detection in detections {
            guard let landmarks = detection.landmarks else {
                continue
            }
            mesh += createMesh(landmark: landmarks.faceContour, image: image)
            mesh += createMesh(landmark: landmarks.leftEye, image: image)
            mesh += createMesh(landmark: landmarks.rightEye, image: image)
            mesh += createMesh(landmark: landmarks.leftEyebrow, image: image)
            mesh += createMesh(landmark: landmarks.rightEyebrow, image: image)
            mesh += createMesh(landmark: landmarks.nose, image: image)
            mesh += createMesh(landmark: landmarks.noseCrest, image: image)
            mesh += createMesh(landmark: landmarks.medianLine, image: image)
            mesh += createMesh(landmark: landmarks.outerLips, image: image)
            mesh += createMesh(landmark: landmarks.innerLips, image: image)
            mesh += createMesh(landmark: landmarks.leftPupil, image: image)
            mesh += createMesh(landmark: landmarks.rightPupil, image: image)
        }
        let filter = CIFilter.meshGenerator()
        filter.color = .green
        filter.width = 3
        filter.mesh = mesh
        guard let outputImage = filter.outputImage else {
            return image
        }
        return outputImage.composited(over: image).cropped(to: image.extent)
    }
}
