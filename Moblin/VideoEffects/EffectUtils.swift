import CoreImage
import Foundation
import Vision

func toPixels(_ percentage: Double, _ total: Double) -> Double {
    return (percentage * total) / 100
}

extension CIImage {
    func resizeMoveMirror(_ sceneWidget: SettingsSceneWidget,
                          _ streamSize: CGSize,
                          _ mirror: Bool) -> CIImage
    {
        var scaleX = toPixels(sceneWidget.width, streamSize.width) / extent.size.width
        var scaleY = toPixels(sceneWidget.height, streamSize.height) / extent.size.height
        let scale = min(scaleX, scaleY)
        if mirror {
            scaleX = -1 * scale
        } else {
            scaleX = scale
        }
        scaleY = scale
        var x = toPixels(sceneWidget.x, streamSize.width)
        if mirror {
            x -= extent.width * scaleX
        }
        let y = streamSize.height - toPixels(sceneWidget.y, streamSize.height) - extent.height * scaleY
        return transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
            .transformed(by: CGAffineTransform(translationX: x, y: y))
    }
}

func addFaceLandmarks(image: CIImage?, detections: [VNFaceObservation]?) -> CIImage? {
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
