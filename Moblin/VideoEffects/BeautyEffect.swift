import MetalPetal
import Vision

final class BeautyEffect: VideoEffect {
    private var smoothnessRadius: Float = 10.0
    private var smoothnessStrength: Float = 0.65
    private var shapePosition: Float = 0.5
    private var shapeRadius: Float = 0.5
    private var shapeStrength: Float = 0.5
    private var shapeScaleFactor: Float = 1.0
    private var lastFaceDetections: [VNFaceObservation] = []
    private var framesPerFade: Float = 30

    init(fps: Float) {
        framesPerFade = 15 * (fps / 30)
    }

    func setSmoothnessSettings(radius: Float, strength: Float) {
        processorPipelineQueue.async {
            self.smoothnessRadius = radius
            self.smoothnessStrength = strength
        }
    }

    func setShapeSettings(position: Float, radius: Float, strength: Float) {
        processorPipelineQueue.async {
            self.shapePosition = position
            self.shapeRadius = radius
            self.shapeStrength = strength
        }
    }

    override func executeMetalPetal(_ image: MTIImage, _ info: VideoEffectInfo) -> MTIImage {
        let detections = info.sceneFaceDetections()
        updateLastFaceDetectionsBefore(info.isFirstAfterAttach)
        updateScaleFactors(detections, info.isFirstAfterAttach)
        var image = image
        if smoothnessStrength > 0 {
            image = addBeautySmoothnessMetalPetal(image) ?? image
        }
        if shapeStrength > 0 {
            image = addBeautyShapeMetalPetal(image, detections, info) ?? image
        }
        updateLastFaceDetectionsAfter(detections)
        return image
    }

    override func isEnabled() -> Bool {
        return smoothnessStrength > 0 || shapeStrength > 0
    }

    override func isMetalPetal() -> Bool {
        return true
    }

    override func needsFaceDetections(_: Double) -> VideoEffectFaceDetectionsMode {
        if shapeStrength > 0 {
            return .now(nil)
        } else {
            return .off
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

    private func addBeautySmoothnessMetalPetal(_ image: MTIImage?) -> MTIImage? {
        let filter = MTIHighPassSkinSmoothingFilter()
        filter.amount = smoothnessStrength
        filter.radius = smoothnessRadius
        filter.inputImage = image
        return filter.outputImage
    }

    private func addBeautyShapeMetalPetal(_ image: MTIImage?,
                                          _ detections: [VNFaceObservation]?,
                                          _: VideoEffectInfo) -> MTIImage?
    {
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
                    (minY + (maxY - minY) * ((shapePosition - 0.5) * 0.5))
                filter.inputImage = outputImage
                filter.center = .init(x: centerX, y: y)
                filter.radius = (maxY - minY) * (0.7 + shapeRadius * 0.3)
                filter.scale = shapeScaleMetalPetal()
                outputImage = filter.outputImage
            }
        }
        return outputImage
    }

    private func shapeScaleMetalPetal() -> Float {
        return -(shapeStrength * 0.075) * shapeScaleFactor
    }
}
