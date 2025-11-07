import CoreImage
import Foundation
import Vision

func toPixels(_ percentage: Double, _ total: Double) -> Double {
    return (percentage * total) / 100
}

extension CIImage {
    func resizeMirror(_ layout: SettingsWidgetLayout,
                      _ streamSize: CGSize,
                      _ mirror: Bool,
                      _ resize: Bool = true) -> CIImage
    {
        guard resize else {
            return self
        }
        var scaleX = toPixels(layout.size, streamSize.width) / extent.size.width
        var scaleY = toPixels(layout.size, streamSize.height) / extent.size.height
        let scale = min(scaleX, scaleY)
        if mirror {
            scaleX = -scale
        } else {
            scaleX = scale
        }
        scaleY = scale
        let scaledImage = scaled(x: scaleX, y: scaleY)
        if mirror {
            return scaledImage.translated(x: scaledImage.extent.width, y: 0)
        } else {
            return scaledImage
        }
    }

    func move(_ layout: SettingsWidgetLayout, _ streamSize: CGSize) -> CIImage {
        let x: Double
        let y: Double
        if layout.alignment.isLeft() {
            x = toPixels(layout.x, streamSize.width) - extent.minX
        } else {
            x = streamSize.width - toPixels(layout.x, streamSize.width) - extent.width - extent.minX
        }
        if layout.alignment.isTop() {
            y = streamSize.height - toPixels(layout.y, streamSize.height) - extent.height - extent.minY
        } else {
            y = toPixels(layout.y, streamSize.height) - extent.minY
        }
        return translated(x: x, y: y)
    }

    func translated(x: Double, y: Double) -> CIImage {
        return transformed(by: CGAffineTransform(translationX: x, y: y))
    }

    func scaled(x: Double, y: Double) -> CIImage {
        return transformed(by: CGAffineTransform(scaleX: x, y: y))
    }

    func scaledTo(size: CGSize) -> CIImage {
        let scaleX = size.width / extent.width
        let scaleY = size.height / extent.height
        let scale = min(scaleX, scaleY)
        return scaled(x: scale, y: scale)
    }

    func centered(size: CGSize) -> CIImage {
        let targetCenterX = size.width / 2
        let targetCenterY = size.height / 2
        let currentCenterX = extent.width / 2
        let currentCenterY = extent.height / 2
        let x = targetCenterX - currentCenterX
        let y = targetCenterY - currentCenterY
        return translated(x: x, y: y)
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
