import Vision

extension VNFaceObservation {
    func stableBoundingBox(imageSize: CGSize, rotationAngle: Double = 0.0) -> CGRect? {
        var allPoints = getFacePoints(imageSize: imageSize)
        if rotationAngle != 0 {
            allPoints = rotateFace(allPoints: allPoints, rotationAngle: -rotationAngle)
        }
        guard let firstPoint = allPoints.first else {
            return nil
        }
        var faceMinX = firstPoint.x
        var faceMaxX = firstPoint.x
        var faceMinY = firstPoint.y
        var faceMaxY = firstPoint.y
        for point in allPoints {
            faceMinX = min(point.x, faceMinX)
            faceMaxX = max(point.x, faceMaxX)
            faceMinY = min(point.y, faceMinY)
            faceMaxY = max(point.y, faceMaxY)
        }
        let faceWidth = faceMaxX - faceMinX
        let faceHeight = faceMaxY - faceMinY
        return CGRect(x: faceMinX, y: faceMinY, width: faceWidth, height: faceHeight)
    }

    func calcFaceAngle(imageSize: CGSize) -> CGFloat? {
        guard let medianLine = landmarks?.medianLine else {
            return nil
        }
        let medianLinePoints = medianLine.pointsInImage(imageSize: imageSize)
        guard let firstPoint = medianLinePoints.first, let lastPoint = medianLinePoints.last else {
            return nil
        }
        let deltaX = firstPoint.x - lastPoint.x
        let deltaY = firstPoint.y - lastPoint.y
        return -atan(deltaX / deltaY)
    }

    func calcFaceAngleSide() -> CGFloat? {
        guard let landmarks,
              let centerPoint = landmarks.medianLine?.normalizedPoints.first,
              let faceContour = landmarks.faceContour?.normalizedPoints,
              let leftPoint = faceContour.first,
              let rightPoint = faceContour.last
        else {
            return nil
        }
        let leftWidth = max(leftPoint.x - centerPoint.x, 0)
        let rightWidth = max(centerPoint.x - rightPoint.x, 0)
        if leftWidth < rightWidth {
            return -(1 - leftWidth / rightWidth)
        } else if leftWidth > rightWidth {
            return 1 - rightWidth / leftWidth
        } else {
            return 0
        }
    }

    func isMouthOpen(rotationAngle: Double) -> Double {
        if let points = landmarks?.innerLips?.normalizedPoints {
            let points = rotateFace(allPoints: points, rotationAngle: -rotationAngle)
            if let boundingBox = calcBoundingBox(points: points) {
                return min(boundingBox.height * 6, 1)
            }
        }
        return 0.0
    }

    func isLeftEyeOpen(rotationAngle: Double) -> Double {
        return isEyeOpen(eye: landmarks?.leftEye, rotationAngle: rotationAngle)
    }

    func isRightEyeOpen(rotationAngle: Double) -> Double {
        return isEyeOpen(eye: landmarks?.rightEye, rotationAngle: rotationAngle)
    }

    //     1   2
    // 0           3
    //     5   4
    private func isEyeOpen(eye: VNFaceLandmarkRegion2D?, rotationAngle: Double) -> Double {
        if let points = eye?.normalizedPoints, points.count == 6 {
            let points = rotateFace(allPoints: points, rotationAngle: -rotationAngle)
            let height = points[1].y - points[5].y
            return height > 0.015 ? 1.0 : 0.0
        }
        return 1.0
    }

    private func getFacePoints(imageSize: CGSize) -> [CGPoint] {
        var points: [CGPoint] = []
        points += landmarks?.medianLine?.pointsInImage(imageSize: imageSize) ?? []
        points += landmarks?.leftEyebrow?.pointsInImage(imageSize: imageSize) ?? []
        points += landmarks?.rightEyebrow?.pointsInImage(imageSize: imageSize) ?? []
        return points
    }
}

func rotateFace(allPoints: [CGPoint], rotationAngle: CGFloat) -> [CGPoint] {
    return allPoints.map { rotatePoint(point: $0, alpha: rotationAngle) }
}

func rotatePoint(point: CGPoint, alpha: CGFloat) -> CGPoint {
    let z = sqrt(pow(point.x, 2) + pow(point.y, 2))
    let beta = atan(point.y / point.x)
    return CGPoint(x: z * cos(alpha + beta), y: z * sin(alpha + beta))
}

func calcBoundingBox(points: [CGPoint]) -> CGRect? {
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
    return CGRect(x: minX, y: maxY, width: width, height: height)
}
