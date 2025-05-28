import SceneKit
import UIKit
import Vision
import VRMSceneKit

final class VTuberEffect: VideoEffect {
    private var videoSourceId: UUID = .init()
    private let scene: VRMScene?
    private let renderer = SCNRenderer(device: nil)
    private var firstPresentationTimeStamp: Double?
    private var previousPresentationTimeStamp = 0.0
    private var neckYAngle = 0.0
    private var neckZAngle = 0.0
    private var latestNeckYAngle = 0.0
    private var latestNeckZAngle = 0.0
    private let cameraNode = SCNNode()
    private var sceneWidget: SettingsSceneWidget?
    private var needsDetectionsPresentationTimeStamp = 0.0

    init(vrm: URL, cameraFieldOfView: Double, cameraPositionY: Double) {
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
        camera.fieldOfView = cameraFieldOfView
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, cameraPositionY, -1.8)
        cameraNode.rotation = SCNVector4(0, 1, 0, Float.pi)
        scene.rootNode.addChildNode(cameraNode)
        renderer.scene = scene
        let node = scene.vrmNode
        node.humanoid.node(for: .leftShoulder)?.eulerAngles = SCNVector3(0, 0, 40 * CGFloat.pi / 180)
        node.humanoid.node(for: .rightShoulder)?.eulerAngles = SCNVector3(0, 0, -40 * CGFloat.pi / 180)
    }

    func setVideoSourceId(videoSourceId: UUID) {
        mixerLockQueue.async {
            self.videoSourceId = videoSourceId
        }
    }

    func setCameraSettings(cameraFieldOfView: Double, cameraPositionY: Double) {
        mixerLockQueue.async {
            self.cameraNode.camera?.fieldOfView = cameraFieldOfView
            self.cameraNode.position = SCNVector3(0, cameraPositionY, -1.8)
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
        let node = scene.vrmNode
        if let detection = info.faceDetections[videoSourceId]?.first,
           let rotationAngle = detection.calcFaceAngle(imageSize: image.extent.size),
           let sideAngle = detection.calcFaceAngleSide()
        {
            let isMouthOpen = detection.isMouthOpen(rotationAngle: rotationAngle)
            node.setBlendShape(value: isMouthOpen, for: .preset(.angry))
            let isLeftEyeOpen = -(detection.isLeftEyeOpen(rotationAngle: rotationAngle) - 1)
            node.setBlendShape(value: isLeftEyeOpen, for: .preset(.blink))
            latestNeckYAngle = sideAngle
            latestNeckZAngle = rotationAngle
        }
        let timeDelta = presentationTimeStamp - previousPresentationTimeStamp
        previousPresentationTimeStamp = presentationTimeStamp
        let newFactor = 0.2 * (timeDelta / 0.033)
        let oldFactor = 1 - newFactor
        neckYAngle = oldFactor * neckYAngle + newFactor * latestNeckYAngle
        neckZAngle = oldFactor * neckZAngle + newFactor * latestNeckZAngle
        node.humanoid.node(for: .neck)?.eulerAngles = SCNVector3(0, -neckYAngle, -neckZAngle)
        let time = presentationTimeStamp - firstPresentationTimeStamp
        var angle = time.remainder(dividingBy: .pi * 2)
        if angle < 0 {
            angle *= -1
        }
        angle -= .pi / 2
        angle *= 0.5
        let armAngle = (angle * 0.1) + .pi / 5
        node.humanoid.node(for: .leftShoulder)?.eulerAngles = SCNVector3(0, 0, armAngle)
        node.humanoid.node(for: .rightShoulder)?.eulerAngles = SCNVector3(0, 0, -armAngle)
        node.update(at: time)
        let width = 300.0 * 2.0
        let height = 300.0 * 2.0
        let vTuberImage = renderer.snapshot(atTime: time,
                                            with: CGSize(width: width, height: height),
                                            antialiasingMode: .none)
        // return addFaceLandmarks(image: image, detections: info.faceDetections[videoSourceId]) ?? image
        guard var vTuberImage = CIImage(image: vTuberImage), let sceneWidget else {
            return image
        }
        vTuberImage = vTuberImage
            .transformed(by: CGAffineTransform(scaleX: 0.5, y: 0.5))
        return vTuberImage
            .transformed(by: makeTranslation(vTuberImage, sceneWidget, image.extent.size))
            .cropped(to: image.extent)
            .composited(over: image)
    }

    override func needsFaceDetections(_ presentationTimeStamp: Double) -> (Bool, UUID?) {
        if presentationTimeStamp - needsDetectionsPresentationTimeStamp >= 0.1 {
            needsDetectionsPresentationTimeStamp = presentationTimeStamp
            return (true, videoSourceId)
        } else {
            return (false, nil)
        }
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
