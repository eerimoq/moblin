import AVFoundation
import UIKit
import Vision

final class FaceEffect: VideoEffect {
    var crop = true
    var showBlur = true
    var showColors = true
    var showMoblin = true
    var showFaceLandmarks = true
    var contrast: Float = 1.0
    var brightness: Float = 0.0
    var saturation: Float = 1.0
    var showBeauty = true
    var shapeRadius: Float = 0.5
    var shapeScale: Float = 0.5
    var shapeOffset: Float = 0.5
    var smoothAmount: Float = 0.65
    var smoothRadius: Float = 20.0
    let moblinImage: CIImage?

    override init() {
        if let image = UIImage(named: "AppIconNoBackground"), let image = image.cgImage {
            moblinImage = CIImage(cgImage: image)
        } else {
            moblinImage = nil
        }
        super.init()
    }

    override func getName() -> String {
        return "face filter"
    }

    override func needsFaceDetections() -> Bool {
        return true
    }

    private func createFacesMaskImage(imageExtent: CGRect, detections: [VNFaceObservation]) -> CIImage? {
        var facesMask = CIImage.empty().cropped(to: imageExtent)
        for detection in detections {
            let faceBoundingBox = CGRect(x: detection.boundingBox.minX * imageExtent.width,
                                         y: detection.boundingBox.minY * imageExtent.height,
                                         width: detection.boundingBox.width * imageExtent.width,
                                         height: detection.boundingBox.height * imageExtent.height)
            let faceCenter = CGPoint(x: faceBoundingBox.maxX - (faceBoundingBox.width / 2),
                                     y: faceBoundingBox.maxY - (faceBoundingBox.height / 2))
            let faceMask = CIFilter.radialGradient()
            faceMask.center = faceCenter
            faceMask.radius0 = Float(faceBoundingBox.height / 2)
            faceMask.radius1 = Float(faceBoundingBox.height)
            faceMask.color0 = CIColor.white
            faceMask.color1 = CIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.0)
            guard let faceMask = faceMask.outputImage?.cropped(to: faceBoundingBox.insetBy(
                dx: -faceBoundingBox.width / 2,
                dy: -faceBoundingBox.height / 2
            )) else {
                continue
            }
            facesMask = faceMask.composited(over: facesMask)
        }
        return facesMask
    }

    private func adjustColorControls(image: CIImage?) -> CIImage? {
        let filter = CIFilter.colorControls()
        filter.inputImage = image
        filter.brightness = brightness
        filter.contrast = contrast
        filter.saturation = saturation
        return filter.outputImage
    }

    private func adjustColors(image: CIImage?) -> CIImage? {
        return adjustColorControls(image: image)
    }

    private func applyBlur(image: CIImage?) -> CIImage? {
        guard let image else {
            return image
        }
        return image
            .clampedToExtent()
            .applyingGaussianBlur(sigma: image.extent.width / 50.0)
            .cropped(to: image.extent)
    }

    private func applyFacesMask(backgroundImage: CIImage?, image: CIImage?,
                                detections: [VNFaceObservation]?) -> CIImage?
    {
        guard let image, let detections else {
            return image
        }
        let faceBlender = CIFilter.blendWithMask()
        faceBlender.inputImage = image
        faceBlender.backgroundImage = backgroundImage
        faceBlender.maskImage = createFacesMaskImage(imageExtent: image.extent, detections: detections)
        return faceBlender.outputImage
    }

    private func addMoblin(image: CIImage?, detections: [VNFaceObservation]?) -> CIImage? {
        guard let image, let detections, let moblinImage else {
            return image
        }
        var outputImage = image
        for detection in detections {
            guard let innerLips = detection.landmarks?.innerLips else {
                continue
            }
            let points = innerLips.pointsInImage(imageSize: image.extent.size)
            guard let firstPoint = points.first else {
                continue
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
            let diffX = maxX - minX
            let diffY = maxY - minY
            if diffY <= diffX {
                continue
            }
            let moblinImage = moblinImage
                .transformed(by: CGAffineTransform(
                    scaleX: diffX / moblinImage.extent.width,
                    y: diffX / moblinImage.extent.width
                ))
            let offsetY = minY + (diffY - moblinImage.extent.height) / 2
            outputImage = moblinImage
                .transformed(by: CGAffineTransform(translationX: minX, y: offsetY))
                .composited(over: outputImage)
        }
        return outputImage.cropped(to: image.extent)
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

    private func addBeauty(image: CIImage?, detections: [VNFaceObservation]?) -> CIImage? {
        guard let image, let detections else {
            return image
        }
        var outputImage: CIImage? = image
        for detection in detections {
            if let medianLine = detection.landmarks?.medianLine {
                let points = medianLine.pointsInImage(imageSize: image.extent.size)
                guard let firstPoint = points.first, let lastPoint = points.last else {
                    continue
                }
                let maxY = firstPoint.y
                let minY = lastPoint.y
                let centerX = lastPoint.x
                let filter = CIFilter.bumpDistortion()
                filter.inputImage = outputImage
                filter.center = CGPoint(
                    x: centerX,
                    y: minY + CGFloat(Float(maxY - minY) * (shapeOffset * 0.4 + 0.1))
                )
                filter.radius = Float(maxY - minY) * (0.7 + shapeRadius * 0.4)
                filter.scale = -(shapeScale * 0.4)
                outputImage = filter.outputImage
            }
        }
        return outputImage?.cropped(to: image.extent)
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
            mesh += createMesh(landmark: landmarks.outerLips, image: image)
            mesh += createMesh(landmark: landmarks.innerLips, image: image)
            mesh += createMesh(landmark: landmarks.leftEye, image: image)
            mesh += createMesh(landmark: landmarks.rightEye, image: image)
            mesh += createMesh(landmark: landmarks.nose, image: image)
            mesh += createMesh(landmark: landmarks.medianLine, image: image)
            mesh += createMesh(landmark: landmarks.leftEyebrow, image: image)
            mesh += createMesh(landmark: landmarks.rightEyebrow, image: image)
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

    override func execute(_ image: CIImage, _ faceDetections: [VNFaceObservation]?) -> CIImage {
        guard let faceDetections else {
            return image
        }
        var outputImage: CIImage? = image
        if showColors {
            outputImage = adjustColors(image: outputImage)
        }
        if showBlur {
            outputImage = applyBlur(image: outputImage)
        }
        if outputImage != image {
            outputImage = applyFacesMask(
                backgroundImage: image,
                image: outputImage,
                detections: faceDetections
            )
        }
        if showMoblin {
            outputImage = addMoblin(image: outputImage, detections: faceDetections)
        }
        if showBeauty {
            outputImage = addBeauty(image: outputImage, detections: faceDetections)
        }
        if showFaceLandmarks {
            outputImage = addFaceLandmarks(image: outputImage, detections: faceDetections)
        }
        if crop {
            let scaleDownFactor = 0.8
            let width = image.extent.width
            let height = image.extent.height
            let scaleUpFactor = 1 / scaleDownFactor
            let smallWidth = width * scaleDownFactor
            let smallHeight = height * scaleDownFactor
            let smallOffsetX = (width - smallWidth) / 2
            let smallOffsetY = (height - smallHeight) / 2
            outputImage = outputImage?
                .cropped(to: CGRect(x: smallOffsetX, y: smallOffsetY, width: smallWidth, height: smallHeight))
                .transformed(by: CGAffineTransform(translationX: -smallOffsetX, y: -smallOffsetY))
                .transformed(by: CGAffineTransform(scaleX: scaleUpFactor, y: scaleUpFactor))
                .cropped(to: image.extent)
        }
        return outputImage ?? image
    }
}
