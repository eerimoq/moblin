import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import MetalPetal

final class VideoEffectsProcessor {
    let context = CIContext()
    private let metalPetalContext: MTIContext?
    var canvasSize = CGSize(width: 1920, height: 1080)
    var fillFrame = true
    var sceneSwitchTransition: SceneSwitchTransition = .blur
    var latestSampleBufferTime: ContinuousClock.Instant?
    private(set) var rotation: Double = 0.0
    private(set) var mirror: Bool = false
    private var effects: [VideoEffect] = []
    private var pendingAfterAttachEffects: [VideoEffect]?
    private var pendingAfterAttachRotation: Double?
    private var pendingAfterAttachMirror: Bool?
    private var isMetalPetalGraphicsForcedByEffects: Bool = false
    private var isMetalPetalGraphics: Bool = false
    private var blackImage: CIImage?
    private var blackImageMetalPetal: MTIImage?
    private var pool: CVPixelBufferPool?
    private var poolColorSpace: CGColorSpace?
    private var poolFormatDescriptionExtension: CFDictionary?
    private var previousFaceDetectionTimes: [UUID: Double] = [:]
    private var previousTextDetectionTimes: [UUID: Double] = [:]

    init() {
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            metalPetalContext = try? MTIContext(device: metalDevice)
        } else {
            metalPetalContext = nil
        }
    }

    func reset() {
        blackImage = nil
        blackImageMetalPetal = nil
        pool = nil
    }

    func setGraphicsImplementation(value: SettingsGraphicsImplementation) {
        switch value {
        case .coreImage:
            isMetalPetalGraphics = false
        case .metalPetal:
            isMetalPetalGraphics = true
        }
    }

    func prepareForAttach() {
        if pendingAfterAttachEffects == nil {
            pendingAfterAttachEffects = effects
        }
        for effect in effects where effect is VideoSourceEffect {
            unregisterEffect(effect)
        }
    }

    func registerEffect(_ effect: VideoEffect) {
        if !effects.contains(effect) {
            effects.append(effect)
        }
    }

    func registerEffectBack(_ effect: VideoEffect) {
        if !effects.contains(effect) {
            effects.insert(effect, at: 0)
        }
    }

    func unregisterEffect(_ effect: VideoEffect) {
        effect.removed()
        if let index = effects.firstIndex(of: effect) {
            effects.remove(at: index)
        }
    }

    func unregisterAllEffects() {
        for effect in effects {
            effect.removed()
        }
        effects.removeAll()
    }

    func setPendingAfterAttachEffects(effects: [VideoEffect], rotation: Double, mirror: Bool) {
        pendingAfterAttachEffects = effects
        pendingAfterAttachRotation = rotation
        pendingAfterAttachMirror = mirror
    }

    func usePendingAfterAttachEffects() {
        if let pendingAfterAttachEffects {
            effects = pendingAfterAttachEffects
            isMetalPetalGraphicsForcedByEffects = effects.contains(where: { $0.isMetalPetal() })
            self.pendingAfterAttachEffects = nil
        }
        if let pendingAfterAttachRotation {
            rotation = pendingAfterAttachRotation
            self.pendingAfterAttachRotation = nil
        }
        if let pendingAfterAttachMirror {
            mirror = pendingAfterAttachMirror
            self.pendingAfterAttachMirror = nil
        }
    }

    func getEnabledEffects() -> [VideoEffect] {
        effects.filter { $0.isEnabled() }
    }

    func removeEffects() {
        effects.removeAll { effect in
            guard effect.shouldRemove() else {
                return false
            }
            effect.removed()
            return true
        }
    }

    func needsFaceDetections(_ enabledEffects: [VideoEffect],
                             _ presentationTimeStamp: Double,
                             _ sceneVideoSourceId: UUID) -> Set<UUID>
    {
        var detectionsIntervals: [UUID: Double] = [:]
        var ids: Set<UUID> = []
        for effect in enabledEffects {
            switch effect.needsFaceDetections(presentationTimeStamp) {
            case .off:
                break
            case let .now(videoSourceId):
                let videoSourceId = videoSourceId ?? sceneVideoSourceId
                ids.insert(videoSourceId)
                previousFaceDetectionTimes[videoSourceId] = presentationTimeStamp
            case let .interval(videoSourceId, interval):
                let videoSourceId = videoSourceId ?? sceneVideoSourceId
                if let currentInterval = detectionsIntervals[videoSourceId] {
                    if interval < currentInterval {
                        detectionsIntervals[videoSourceId] = interval
                    }
                } else {
                    detectionsIntervals[videoSourceId] = interval
                }
            }
        }
        for (videoSourceId, interval) in detectionsIntervals {
            if let previousPresentationTimeStamp = previousFaceDetectionTimes[videoSourceId] {
                if presentationTimeStamp - previousPresentationTimeStamp > interval {
                    ids.insert(videoSourceId)
                    previousFaceDetectionTimes[videoSourceId] = presentationTimeStamp
                }
            } else {
                ids.insert(videoSourceId)
                previousFaceDetectionTimes[videoSourceId] = presentationTimeStamp
            }
        }
        return ids
    }

    func needsTextDetections(_ enabledEffects: [VideoEffect],
                             _ presentationTimeStamp: Double,
                             _ sceneVideoSourceId: UUID) -> Set<UUID>
    {
        var detectionsIntervals: [UUID: Double] = [:]
        var ids: Set<UUID> = []
        for effect in enabledEffects {
            switch effect.needsTextDetections(presentationTimeStamp) {
            case .off:
                break
            case let .now(videoSourceId):
                let videoSourceId = videoSourceId ?? sceneVideoSourceId
                ids.insert(videoSourceId)
                previousTextDetectionTimes[videoSourceId] = presentationTimeStamp
            case let .interval(videoSourceId, interval):
                let videoSourceId = videoSourceId ?? sceneVideoSourceId
                if let currentInterval = detectionsIntervals[videoSourceId] {
                    if interval < currentInterval {
                        detectionsIntervals[videoSourceId] = interval
                    }
                } else {
                    detectionsIntervals[videoSourceId] = interval
                }
            }
        }
        for (videoSourceId, interval) in detectionsIntervals {
            if let previousPresentationTimeStamp = previousTextDetectionTimes[videoSourceId] {
                if presentationTimeStamp - previousPresentationTimeStamp > interval {
                    ids.insert(videoSourceId)
                    previousTextDetectionTimes[videoSourceId] = presentationTimeStamp
                }
            } else {
                ids.insert(videoSourceId)
                previousTextDetectionTimes[videoSourceId] = presentationTimeStamp
            }
        }
        return ids
    }

    func applyEffects(_ imageBuffer: CVImageBuffer,
                      _ sampleBuffer: CMSampleBuffer,
                      _ enabledEffects: [VideoEffect],
                      _ sceneVideoSourceId: UUID,
                      _ detectionJobs: [DetectionJob],
                      _ detections: [UUID: Detections],
                      _ isSceneSwitchTransition: Bool,
                      _ isFirstAfterAttach: Bool,
                      _ videoUnit: VideoUnit,
                      _ videoOrientation: AVCaptureVideoOrientation) -> (CVImageBuffer?, CMSampleBuffer?)
    {
        let info = VideoEffectInfo(
            sceneVideoSourceId: sceneVideoSourceId,
            detectionJobs: detectionJobs,
            detections: detections,
            presentationTimeStamp: sampleBuffer.presentationTimeStamp,
            videoUnit: videoUnit,
            isFirstAfterAttach: isFirstAfterAttach
        )
        if isMetalPetalGraphicsEnabled() {
            return applyEffectsMetalPetal(
                imageBuffer,
                sampleBuffer,
                enabledEffects,
                isSceneSwitchTransition,
                videoOrientation,
                info
            )
        } else {
            return applyEffectsCoreImage(
                imageBuffer,
                sampleBuffer,
                enabledEffects,
                isSceneSwitchTransition,
                videoOrientation,
                info
            )
        }
    }

    func isAtEndOfSceneSwitchTransition() -> Bool {
        if let latestSampleBufferTime {
            let offset = ContinuousClock.now - latestSampleBufferTime
            if sceneSwitchTransition == .blurAndZoom {
                return offset.seconds >= 5
            } else {
                return offset.seconds >= 2
            }
        } else {
            return false
        }
    }

    func renderSceneSwitchTransitionEnd(_ sampleBuffer: CMSampleBuffer,
                                        _ imageBuffer: CVImageBuffer,
                                        _ outputImageBuffer: CVPixelBuffer) -> CMSampleBuffer
    {
        if isMetalPetalGraphicsEnabled() {
            let image = MTIImage(cvPixelBuffer: imageBuffer, alphaType: .alphaIsOne)
            do {
                try metalPetalContext?.render(applySceneSwitchTransitionMetalPetal(image),
                                              to: outputImageBuffer)
            } catch {
                return sampleBuffer
            }
        } else {
            let image = applySceneSwitchTransition(CIImage(cvPixelBuffer: imageBuffer))
            if let poolColorSpace {
                context.render(image, to: outputImageBuffer, bounds: image.extent, colorSpace: poolColorSpace)
            } else {
                context.render(image, to: outputImageBuffer)
            }
        }
        guard let formatDescription = CMVideoFormatDescription.create(imageBuffer: outputImageBuffer)
        else {
            return sampleBuffer
        }
        guard let outputSampleBuffer = CMSampleBuffer.create(outputImageBuffer,
                                                             formatDescription,
                                                             sampleBuffer.duration,
                                                             sampleBuffer.presentationTimeStamp,
                                                             sampleBuffer.decodeTimeStamp)
        else {
            return sampleBuffer
        }
        return outputSampleBuffer
    }

    private func isMetalPetalGraphicsEnabled() -> Bool {
        isMetalPetalGraphics || isMetalPetalGraphicsForcedByEffects
    }

    private func getBufferPool(formatDescription: CMFormatDescription) -> CVPixelBufferPool? {
        let formatDescriptionExtension = formatDescription.extensions()
        if let pool, formatDescriptionExtension == poolFormatDescriptionExtension {
            return pool
        }
        var pixelBufferAttributes: [NSString: AnyObject] = [
            kCVPixelBufferPixelFormatTypeKey: NSNumber(value: pixelFormatType),
            kCVPixelBufferIOSurfacePropertiesKey: NSDictionary(),
            kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferWidthKey: NSNumber(value: canvasSize.width),
            kCVPixelBufferHeightKey: NSNumber(value: canvasSize.height),
        ]
        poolColorSpace = nil
        // This is not correct, I'm sure. Colors are not always correct. At least for Apple Log.
        if let formatDescriptionExtension = formatDescriptionExtension as Dictionary? {
            let colorPrimaries = formatDescriptionExtension[kCVImageBufferColorPrimariesKey]
            if let colorPrimaries {
                var colorSpaceProperties: [NSString: AnyObject] =
                    [kCVImageBufferColorPrimariesKey: colorPrimaries]
                if let yCbCrMatrix = formatDescriptionExtension[kCVImageBufferYCbCrMatrixKey] {
                    colorSpaceProperties[kCVImageBufferYCbCrMatrixKey] = yCbCrMatrix
                }
                if let transferFunction = formatDescriptionExtension[kCVImageBufferTransferFunctionKey] {
                    colorSpaceProperties[kCVImageBufferTransferFunctionKey] = transferFunction
                }
                pixelBufferAttributes[kCVBufferPropagatedAttachmentsKey] = colorSpaceProperties as AnyObject
            }
            if let colorSpace = formatDescriptionExtension[kCVImageBufferCGColorSpaceKey] {
                poolColorSpace = (colorSpace as! CGColorSpace)
            } else if let colorPrimaries = colorPrimaries as? String {
                if colorPrimaries == (kCVImageBufferColorPrimaries_P3_D65 as String) {
                    poolColorSpace = CGColorSpace(name: CGColorSpace.displayP3)
                } else if #available(iOS 17.2, *),
                          formatDescriptionExtension[kCVImageBufferLogTransferFunctionKey] as? String ==
                          kCVImageBufferLogTransferFunction_AppleLog as String
                {
                    poolColorSpace = CGColorSpace(name: CGColorSpace.itur_2020)
                    // poolColorSpace = CGColorSpace(name: CGColorSpace.extendedITUR_2020)
                    // poolColorSpace = CGColorSpace(name: CGColorSpace.displayP3)
                    // poolColorSpace = nil
                }
            }
        }
        poolFormatDescriptionExtension = formatDescriptionExtension
        pool = nil
        CVPixelBufferPoolCreate(
            nil,
            nil,
            pixelBufferAttributes as NSDictionary?,
            &pool
        )
        return pool
    }

    private func createPixelBuffer(sampleBuffer: CMSampleBuffer) -> CVPixelBuffer? {
        guard let pool = getBufferPool(formatDescription: sampleBuffer.formatDescription!) else {
            return nil
        }
        var outputImageBuffer: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &outputImageBuffer) == kCVReturnSuccess else {
            return nil
        }
        return outputImageBuffer
    }

    private func getBlackImage(width: Double, height: Double) -> CIImage {
        if blackImage == nil {
            blackImage = createBlackImage(width: width, height: height)
        }
        return blackImage!
    }

    private func scaleImage(_ image: CIImage) -> CIImage {
        let scaleFactor = calcScaleFactor(image.extent.size)
        let x = (canvasSize.width - image.extent.width * scaleFactor) / 2
        let y = (canvasSize.height - image.extent.height * scaleFactor) / 2
        return image
            .scaled(x: scaleFactor, y: scaleFactor)
            .translated(x: x, y: y)
            .cropped(to: CGRect(x: 0, y: 0, width: canvasSize.width, height: canvasSize.height))
            .composited(over: getBlackImage(
                width: Double(canvasSize.width),
                height: Double(canvasSize.height)
            ))
    }

    private func getBlackImageMetalPetal(size: CGSize) -> MTIImage {
        if blackImageMetalPetal == nil {
            blackImageMetalPetal = MTIImage(color: .black, sRGB: false, size: size)
        }
        return blackImageMetalPetal!
    }

    private func calcScaleFactor(_ size: CGSize) -> Double {
        let imageRatio = size.height / size.width
        let canvasRatio = canvasSize.height / canvasSize.width
        if (fillFrame && (canvasRatio < imageRatio)) || (!fillFrame && (canvasRatio > imageRatio)) {
            return canvasSize.width / size.width
        } else {
            return canvasSize.height / size.height
        }
    }

    private func scaleImageMetalPetal(_ image: MTIImage, _ rotation: Double) -> MTIImage {
        var shape = MetalPetalWidgetShape(contentRegion: image.extent)
        shape.rotation = rotation
        let scaleFactor = calcScaleFactor(shape.rotated(image.size))
        let size = CGSize(width: image.size.width * scaleFactor, height: image.size.height * scaleFactor)
        let position = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        let filter = MTIMultilayerCompositingFilter()
        filter.inputBackgroundImage = getBlackImageMetalPetal(size: canvasSize)
        filter.layers = [
            .init(content: image,
                  contentFlipOptions: mirror ? shape.mirrorFlipOptions() : [],
                  position: position,
                  size: size,
                  rotation: shape.rotationRadians()),
        ]
        return filter.outputImage ?? image
    }

    private func rotateCoreImage(_ image: CIImage, _ rotation: Double) -> CIImage {
        switch rotation {
        case 90:
            image.oriented(.right)
        case 180:
            image.oriented(.down)
        case 270:
            image.oriented(.left)
        default:
            image
        }
    }

    private func mirrorCoreImage(_ image: CIImage) -> CIImage {
        image.scaled(x: -1, y: 1).translated(x: image.extent.width, y: 0)
    }

    private func applyEffectsCoreImage(_ imageBuffer: CVImageBuffer,
                                       _ sampleBuffer: CMSampleBuffer,
                                       _ enabledEffects: [VideoEffect],
                                       _ isSceneSwitchTransition: Bool,
                                       _ videoOrientation: AVCaptureVideoOrientation,
                                       _ info: VideoEffectInfo) -> (CVImageBuffer?, CMSampleBuffer?)
    {
        var image = CIImage(cvPixelBuffer: imageBuffer)
        let originalImage = image
        if videoOrientation != .portrait, imageBuffer.isPortrait() {
            image = image.oriented(.left)
        }
        image = rotateCoreImage(image, rotation)
        if mirror {
            image = mirrorCoreImage(image)
        }
        if image.extent.size != canvasSize {
            image = scaleImage(image)
        }
        let extent = image.extent
        if isSceneSwitchTransition {
            image = applySceneSwitchTransition(image)
        }
        for effect in enabledEffects {
            let effectOutputImage = effect.execute(image, info)
            if effectOutputImage.extent == extent {
                image = effectOutputImage
            }
        }
        guard image !== originalImage else {
            return (nil, nil)
        }
        guard let outputImageBuffer = createPixelBuffer(sampleBuffer: sampleBuffer) else {
            return (nil, nil)
        }
        if let poolColorSpace {
            context.render(image, to: outputImageBuffer, bounds: extent, colorSpace: poolColorSpace)
        } else {
            context.render(image, to: outputImageBuffer)
        }
        guard let formatDescription = CMVideoFormatDescription.create(imageBuffer: outputImageBuffer)
        else {
            return (nil, nil)
        }
        guard let outputSampleBuffer = CMSampleBuffer.create(outputImageBuffer,
                                                             formatDescription,
                                                             sampleBuffer.duration,
                                                             sampleBuffer.presentationTimeStamp,
                                                             sampleBuffer.decodeTimeStamp)
        else {
            return (nil, nil)
        }
        return (outputImageBuffer, outputSampleBuffer)
    }

    private func applyEffectsMetalPetal(_ imageBuffer: CVImageBuffer,
                                        _ sampleBuffer: CMSampleBuffer,
                                        _ enabledEffects: [VideoEffect],
                                        _ isSceneSwitchTransition: Bool,
                                        _ videoOrientation: AVCaptureVideoOrientation,
                                        _ info: VideoEffectInfo) -> (CVImageBuffer?, CMSampleBuffer?)
    {
        let image: MTIImage? = MTIImage(cvPixelBuffer: imageBuffer, alphaType: .alphaIsOne)
        let originalImage = image
        guard var image else {
            return (nil, nil)
        }
        var rotation = rotation
        if videoOrientation != .portrait, imageBuffer.isPortrait() {
            rotation = (rotation + 270).truncatingRemainder(dividingBy: 360)
        }
        if image.size != canvasSize || rotation != 0 || mirror {
            image = scaleImageMetalPetal(image, rotation)
        }
        if isSceneSwitchTransition {
            image = applySceneSwitchTransitionMetalPetal(image)
        }
        for effect in enabledEffects {
            image = effect.executeMetalPetal(image, info)
        }
        guard image != originalImage,
              let outputImageBuffer = createPixelBuffer(sampleBuffer: sampleBuffer)
        else {
            return (nil, nil)
        }
        do {
            try metalPetalContext?.render(image, to: outputImageBuffer)
        } catch {
            logger.info("video-unit: Metal petal error: \(error)")
            return (nil, nil)
        }
        guard let formatDescription = CMVideoFormatDescription.create(imageBuffer: outputImageBuffer)
        else {
            return (nil, nil)
        }
        guard let outputSampleBuffer = CMSampleBuffer.create(outputImageBuffer,
                                                             formatDescription,
                                                             sampleBuffer.duration,
                                                             sampleBuffer.presentationTimeStamp,
                                                             sampleBuffer.decodeTimeStamp)
        else {
            return (nil, nil)
        }
        return (outputImageBuffer, outputSampleBuffer)
    }

    private func calcBlurRadius() -> Float {
        if let latestSampleBufferTime {
            let offset = ContinuousClock.now - latestSampleBufferTime
            if sceneSwitchTransition == .blurAndZoom {
                return 0 + min(Float(offset.seconds), 5) * 5
            } else {
                return 15 + min(Float(offset.seconds), 2) * 15
            }
        } else {
            return 25
        }
    }

    private func calcBlurScale() -> Double {
        if let latestSampleBufferTime {
            let offset = ContinuousClock.now - latestSampleBufferTime
            return 1.0 - min(offset.seconds, 5) * 0.05
        } else {
            return 0.75
        }
    }

    private func applySceneSwitchTransition(_ image: CIImage) -> CIImage {
        switch sceneSwitchTransition {
        case .blur:
            let filter = CIFilter.gaussianBlur()
            filter.inputImage = image
            filter.radius = calcBlurRadius() * Float(image.extent.size.maximum() / 1920)
            return filter.outputImage?.cropped(to: image.extent) ?? image
        case .freeze:
            return image
        case .blurAndZoom:
            let filter = CIFilter.gaussianBlur()
            filter.inputImage = image
            filter.radius = calcBlurRadius() * Float(image.extent.size.maximum() / 1920)
            let width = image.extent.width
            let height = image.extent.height
            let cropScaleDownFactor = calcBlurScale()
            let scaleUpFactor = 1 / cropScaleDownFactor
            let smallWidth = width * cropScaleDownFactor
            let smallHeight = height * cropScaleDownFactor
            let smallOffsetX = (width - smallWidth) / 2
            let smallOffsetY = (height - smallHeight) / 2
            return filter.outputImage?
                .cropped(to: CGRect(x: smallOffsetX, y: smallOffsetY, width: smallWidth, height: smallHeight))
                .translated(x: -smallOffsetX, y: -smallOffsetY)
                .scaled(x: scaleUpFactor, y: scaleUpFactor)
                .cropped(to: image.extent) ?? image
        }
    }

    private func blurMetalPetal(_ image: MTIImage) -> MTIImage {
        let filter = MTIMPSGaussianBlurFilter()
        filter.inputImage = image
        filter.radius = calcBlurRadius() * Float(image.extent.size.maximum() / 1920)
        return filter.outputImage ?? image
    }

    private func applySceneSwitchTransitionMetalPetal(_ image: MTIImage) -> MTIImage {
        switch sceneSwitchTransition {
        case .blur:
            return blurMetalPetal(image)
        case .freeze:
            return image
        case .blurAndZoom:
            let cropScaleDownFactor = calcBlurScale()
            let filter = MTICropFilter()
            filter.inputImage = blurMetalPetal(image)
            filter.cropRegion = .fractional(CGRect(x: (1 - cropScaleDownFactor) / 2,
                                                   y: (1 - cropScaleDownFactor) / 2,
                                                   width: cropScaleDownFactor,
                                                   height: cropScaleDownFactor))
            filter.scale = Float(1 / cropScaleDownFactor)
            return filter.outputImage ?? image
        }
    }
}
