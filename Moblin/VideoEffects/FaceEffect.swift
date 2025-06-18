import AVFoundation
import MetalPetal
import UIKit
import Vision

struct FaceEffectSettings {
    var showCrop = true
    var showBlur = true
    var showBlurBackground = true
    var showMouth = true
    var showBeauty = true
    var shapeRadius: Float = 0.5
    var shapeAmount: Float = 0.5
    var shapeOffset: Float = 0.5
    var smoothAmount: Float = 0.65
    var smoothRadius: Float = 20.0
}

private let cropScaleDownFactor = 0.8

final class FaceEffect: VideoEffect {
    var safeSettings = Atomic<FaceEffectSettings>(.init())
    private var settings = FaceEffectSettings()
    let moblinImage: CIImage?
    let moblinImageMetalPetal: MTIImage?
    private var findFace = false
    private var onFindFaceChanged: ((Bool) -> Void)?
    private var shapeScaleFactor: Float = 0.0
    private var lastFaceDetections: [VNFaceObservation] = []
    private var framesPerFade: Float = 30

    init(fps: Float) {
        framesPerFade = 15 * (fps / 30)
        if let image = UIImage(named: "AppIconNoBackground"), let image = image.cgImage {
            moblinImage = CIImage(cgImage: image)
            moblinImageMetalPetal = MTIImage(cgImage: image, isOpaque: true)
        } else {
            moblinImage = nil
            moblinImageMetalPetal = nil
        }
        super.init()
    }

    convenience init(fps: Float, onFindFaceChanged: @escaping (Bool) -> Void) {
        self.init(fps: fps)
        self.onFindFaceChanged = onFindFaceChanged
    }

    override func getName() -> String {
        return "face filter"
    }

    override func needsFaceDetections(_: Double) -> (Bool, UUID?, Double?) {
        return (true, nil, nil)
    }

    private func findFaceNeeded() -> Bool {
        return settings.showBeauty && settings.shapeAmount > 0
    }

    private func updateFindFace(_ faceDetections: [VNFaceObservation]?) {
        if findFace {
            if findFaceNeeded() {
                if let faceDetections, !faceDetections.isEmpty {
                    findFace = false
                    onFindFaceChanged?(findFace)
                }
            } else {
                findFace = false
                onFindFaceChanged?(findFace)
            }
        } else {
            if findFaceNeeded() {
                if let faceDetections, faceDetections.isEmpty {
                    findFace = true
                    onFindFaceChanged?(findFace)
                }
            }
        }
    }

    private func addBlur(image: CIImage?) -> CIImage? {
        guard let image else {
            return image
        }
        return image
            .clampedToExtent()
            .applyingGaussianBlur(sigma: image.extent.width / 50.0)
            .cropped(to: image.extent)
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

    private func applyFacesMask(image: CIImage?,
                                detections: [VNFaceObservation]?,
                                blurFaces: Bool,
                                blurBackground: Bool) -> CIImage?
    {
        guard let image, let detections else {
            return image
        }
        let blurredImage = addBlur(image: image)
        let mask = createFacesMaskImage(imageExtent: image.extent, detections: detections)
        var outputImage: CIImage? = blurredImage
        if blurFaces {
            let faceBlender = CIFilter.blendWithMask()
            faceBlender.inputImage = blurredImage
            faceBlender.backgroundImage = image
            faceBlender.maskImage = mask
            outputImage = faceBlender.outputImage
        } else {
            outputImage = image
        }
        if blurBackground {
            let faceBlender = CIFilter.blendWithMask()
            faceBlender.inputImage = outputImage
            faceBlender.backgroundImage = blurredImage
            faceBlender.maskImage = mask
            outputImage = faceBlender.outputImage
        }
        return outputImage
    }

    private func addMouth(image: CIImage?, detections: [VNFaceObservation]?) -> CIImage? {
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

    private func addBeauty(_ image: CIImage?, _ detections: [VNFaceObservation]?) -> CIImage? {
        guard let image, var detections else {
            return image
        }
        if detections.isEmpty {
            detections = lastFaceDetections
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
                    y: minY + CGFloat(Float(maxY - minY) * ((settings.shapeOffset - 0.5) * 0.5))
                )
                filter.radius = Float(maxY - minY) * (0.85 + settings.shapeRadius * 0.3)
                filter.scale = shapeScale()
                outputImage = filter.outputImage
            }
        }
        return outputImage?.cropped(to: image.extent)
    }

    private func shapeScale() -> Float {
        return -(settings.shapeAmount * 0.15) * shapeScaleFactor
    }

    private func loadSettings() {
        settings = safeSettings.value
    }

    override func execute(_ image: CIImage, _ info: VideoEffectInfo) -> CIImage {
        let faceDetections = info.sceneFaceDetections()
        let isFirstAfterAttach = info.isFirstAfterAttach
        loadSettings()
        updateFindFace(faceDetections)
        updateLastFaceDetectionsBefore(isFirstAfterAttach)
        updateScaleFactors(faceDetections, isFirstAfterAttach)
        guard let faceDetections else {
            return image
        }
        var outputImage: CIImage? = image
        if settings.showBlur || settings.showBlurBackground {
            outputImage = applyFacesMask(
                image: image,
                detections: faceDetections,
                blurFaces: settings.showBlur,
                blurBackground: settings.showBlurBackground
            )
        }
        if settings.showBeauty {
            outputImage = addBeauty(outputImage, faceDetections)
        }
        if settings.showMouth {
            outputImage = addMouth(image: outputImage, detections: faceDetections)
        }
        if settings.showCrop {
            let width = image.extent.width
            let height = image.extent.height
            let scaleUpFactor = 1 / cropScaleDownFactor
            let smallWidth = width * cropScaleDownFactor
            let smallHeight = height * cropScaleDownFactor
            let smallOffsetX = (width - smallWidth) / 2
            let smallOffsetY = (height - smallHeight) / 2
            outputImage = outputImage?
                .cropped(to: CGRect(x: smallOffsetX, y: smallOffsetY, width: smallWidth, height: smallHeight))
                .transformed(by: CGAffineTransform(translationX: -smallOffsetX, y: -smallOffsetY))
                .transformed(by: CGAffineTransform(scaleX: scaleUpFactor, y: scaleUpFactor))
                .cropped(to: image.extent)
        }
        updateLastFaceDetectionsAfter(faceDetections)
        return outputImage ?? image
    }

    private func createFacesMaskImageMetalPetal(imageExtent: CGRect,
                                                detections: [VNFaceObservation]) -> MTIImage?
    {
        var faceMasks: [MTILayer] = []
        for detection in detections {
            let faceBoundingBox = CGRect(x: detection.boundingBox.minX * imageExtent.width,
                                         y: detection.boundingBox.minY * imageExtent.height,
                                         width: detection.boundingBox.width * imageExtent.width,
                                         height: detection.boundingBox.height * imageExtent.height)
            let faceCenter = CGPoint(x: faceBoundingBox.maxX - (faceBoundingBox.width / 2),
                                     y: imageExtent
                                         .height - (faceBoundingBox.maxY - (faceBoundingBox.height / 2)))
            let faceMask = MTIImage.radialGradient(size: .init(
                width: faceBoundingBox.width * 2,
                height: faceBoundingBox.height * 2
            ))
            faceMasks.append(.init(content: faceMask, position: faceCenter))
        }
        let filter = MTIMultilayerCompositingFilter()
        filter.inputBackgroundImage = MTIImage(color: .black, sRGB: true, size: imageExtent.size)
        filter.layers = faceMasks
        return filter.outputImage
    }

    private func addBlurMetalPetal(image: MTIImage?) -> MTIImage? {
        guard let image else {
            return image
        }
        let filter = MTIMPSGaussianBlurFilter()
        filter.inputImage = image
        filter.radius = Float(50 * (image.extent.size.maximum() / 1920))
        return filter.outputImage
    }

    private func applyFacesMaskMetalPetal(backgroundImage: MTIImage?, image: MTIImage?,
                                          detections: [VNFaceObservation]?) -> MTIImage?
    {
        guard let image, let detections else {
            return image
        }
        guard let faceMasksImage = createFacesMaskImageMetalPetal(
            imageExtent: image.extent,
            detections: detections
        ) else {
            return image
        }
        let filter = MTIBlendWithMaskFilter()
        filter.inputImage = image
        filter.inputBackgroundImage = backgroundImage
        filter.inputMask = MTIMask(content: faceMasksImage)
        return filter.outputImage
    }

    private func addMouthMetalPetal(image: MTIImage?, detections: [VNFaceObservation]?) -> MTIImage? {
        guard let image, let detections, let moblinImageMetalPetal else {
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
            let scale = diffX / moblinImageMetalPetal.extent.width
            let moblinImageMetalPetal = moblinImageMetalPetal.resized(to: .init(
                width: scale * moblinImageMetalPetal.size.width,
                height: scale * moblinImageMetalPetal.size.height
            ))
            guard let moblinImageMetalPetal else {
                continue
            }
            let offsetX = minX + moblinImageMetalPetal.size.width / 2
            let offsetY = image.size.height - minY - diffY + moblinImageMetalPetal.size.height / 2
            let filter = MTIMultilayerCompositingFilter()
            filter.inputBackgroundImage = outputImage
            filter.layers = [
                .init(content: moblinImageMetalPetal, position: .init(x: offsetX, y: offsetY)),
            ]
            outputImage = filter.outputImage ?? outputImage
        }
        return outputImage
    }

    private func addBeautyMetalPetal(_ image: MTIImage?, _ detections: [VNFaceObservation]?) -> MTIImage? {
        var image = image
        if settings.smoothAmount > 0 {
            image = addBeautySmoothMetalPetal(image)
        }
        if settings.shapeAmount > 0 {
            image = addBeautyShapeMetalPetal(image, detections)
        }
        return image
    }

    private func addBeautySmoothMetalPetal(_ image: MTIImage?) -> MTIImage? {
        let filter = MTIHighPassSkinSmoothingFilter()
        filter.amount = settings.smoothAmount
        filter.radius = settings.smoothRadius
        filter.inputImage = image
        return filter.outputImage
    }

    private func addBeautyShapeMetalPetal(_ image: MTIImage?, _ detections: [VNFaceObservation]?) -> MTIImage? {
        guard let image, var detections else {
            return image
        }
        if detections.isEmpty {
            detections = lastFaceDetections
        }
        var outputImage: MTIImage? = image
        for detection in detections {
            if let medianLine = detection.landmarks?.medianLine {
                let points = medianLine.pointsInImage(imageSize: image.extent.size)
                guard let firstPoint = points.first, let lastPoint = points.last else {
                    continue
                }
                let maxY = Float(firstPoint.y)
                let minY = Float(lastPoint.y)
                let centerX = Float(lastPoint.x)
                let filter = MTIBulgeDistortionFilter()
                let y = Float(image.size.height) -
                    (minY + (maxY - minY) * ((settings.shapeOffset - 0.5) * 0.5))
                filter.inputImage = outputImage
                filter.center = .init(x: centerX, y: y)
                filter.radius = (maxY - minY) * (0.7 + settings.shapeRadius * 0.3)
                filter.scale = shapeScaleMetalPetal()
                outputImage = filter.outputImage
            }
        }
        return outputImage
    }

    private func shapeScaleMetalPetal() -> Float {
        return -(settings.shapeAmount * 0.075) * shapeScaleFactor
    }

    private func increaseShapeScaleFactor() {
        shapeScaleFactor = min(shapeScaleFactor + (1.0 / framesPerFade), 1)
    }

    private func decreaseShapeScaleFactor() {
        shapeScaleFactor = max(shapeScaleFactor - (1.0 / framesPerFade), 0)
    }

    private func updateScaleFactors(_ detections: [VNFaceObservation]?, _ isFirstAfterAttach: Bool) {
        if isFirstAfterAttach {
            shapeScaleFactor = 1
        } else {
            if detections?.isEmpty ?? true {
                decreaseShapeScaleFactor()
            } else {
                increaseShapeScaleFactor()
            }
        }
    }

    private func updateLastFaceDetectionsBefore(_ isFirstAfterAttach: Bool) {
        if isFirstAfterAttach {
            lastFaceDetections = .init()
        }
    }

    private func updateLastFaceDetectionsAfter(_ faceDetections: [VNFaceObservation]?) {
        if let faceDetections, !faceDetections.isEmpty {
            lastFaceDetections = faceDetections
        }
    }

    override func executeMetalPetal(_ image: MTIImage?, _ info: VideoEffectInfo) -> MTIImage? {
        let faceDetections = info.sceneFaceDetections()
        let isFirstAfterAttach = info.isFirstAfterAttach
        loadSettings()
        updateFindFace(faceDetections)
        updateLastFaceDetectionsBefore(isFirstAfterAttach)
        updateScaleFactors(faceDetections, isFirstAfterAttach)
        var outputImage = image
        guard let image else {
            return image
        }
        if settings.showBlur {
            outputImage = addBlurMetalPetal(image: outputImage)
        }
        if outputImage != image {
            outputImage = applyFacesMaskMetalPetal(
                backgroundImage: image,
                image: outputImage,
                detections: faceDetections
            )
        }
        if settings.showBeauty {
            outputImage = addBeautyMetalPetal(outputImage, faceDetections)
        }
        if settings.showMouth {
            outputImage = addMouthMetalPetal(image: outputImage, detections: faceDetections)
        }
        if settings.showCrop {
            let width = image.extent.width
            let height = image.extent.height
            let smallWidth = width * cropScaleDownFactor
            let smallHeight = height * cropScaleDownFactor
            let smallOffsetX = (width - smallWidth) / 2
            let smallOffsetY = (height - smallHeight) / 2
            outputImage = outputImage?
                .cropped(to: CGRect(
                    x: smallOffsetX,
                    y: smallOffsetY,
                    width: smallWidth,
                    height: smallHeight
                ))?
                .resized(to: image.size)
        }
        updateLastFaceDetectionsAfter(faceDetections)
        return outputImage
    }

    override func removed() {
        findFace = false
        onFindFaceChanged?(findFace)
    }
}
