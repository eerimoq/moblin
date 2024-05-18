import AVFoundation
import CoreImage
import MetalPetal
import UIKit
import Vision

var ioVideoBlurSceneSwitch = true
var ioVideoUnitIgnoreFramesAfterAttachSeconds = 0.3
var ioVideoUnitWatchInterval = 1.0
var pixelFormatType = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
var ioVideoUnitMetalPetal = false
private let lockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.VideoIOComponent")
private let detectionsQueue = DispatchQueue(
    label: "com.haishinkit.HaishinKit.Detections",
    attributes: .concurrent
)
private let lowFpsImageQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.VideoIOComponent.small")

private func setOrientation(
    device: AVCaptureDevice?,
    connection: AVCaptureConnection,
    orientation: AVCaptureVideoOrientation
) {
    if #available(iOS 17.0, *), device?.deviceType == .external {
        connection.videoOrientation = .landscapeRight
    } else {
        connection.videoOrientation = orientation
    }
}

private struct FaceDetectionsCompletion {
    let sequenceNumber: UInt64
    let sampleBuffer: CMSampleBuffer
    let isFirstAfterAttach: Bool
    let applyBlur: Bool
    var faceDetections: [VNFaceObservation]?
}

private class ReplaceVideo {
    var sampleBuffers: [CMSampleBuffer] = []
    var firstPresentationTimeStamp: Double = .nan
    var currentSampleBuffer: CMSampleBuffer?
    var latency: Double

    init(latency: Double) {
        self.latency = latency
    }

    func updateSampleBuffer(_ realPresentationTimeStamp: Double) {
        var sampleBuffer = currentSampleBuffer
        while !sampleBuffers.isEmpty {
            let replaceSampleBuffer = sampleBuffers.first!
            // Get first frame quickly
            if currentSampleBuffer == nil {
                sampleBuffer = replaceSampleBuffer
            }
            // Just for sanity. Should depend on FPS and latency.
            if sampleBuffers.count > 200 {
                // logger.info("Over 200 frames buffered. Dropping oldest frame.")
                sampleBuffer = replaceSampleBuffer
                sampleBuffers.remove(at: 0)
                continue
            }
            let presentationTimeStamp = replaceSampleBuffer.presentationTimeStamp.seconds
            if firstPresentationTimeStamp.isNaN {
                firstPresentationTimeStamp = realPresentationTimeStamp - presentationTimeStamp
            }
            if firstPresentationTimeStamp + presentationTimeStamp + latency > realPresentationTimeStamp {
                break
            }
            sampleBuffer = replaceSampleBuffer
            sampleBuffers.remove(at: 0)
        }
        currentSampleBuffer = sampleBuffer
    }

    func getSampleBuffer(_ realSampleBuffer: CMSampleBuffer) -> CMSampleBuffer? {
        if let currentSampleBuffer {
            return makeSampleBuffer(
                realSampleBuffer: realSampleBuffer,
                replaceSampleBuffer: currentSampleBuffer
            )
        } else {
            return nil
        }
    }

    private func makeSampleBuffer(realSampleBuffer: CMSampleBuffer,
                                  replaceSampleBuffer: CMSampleBuffer) -> CMSampleBuffer?
    {
        guard let sampleBuffer = CMSampleBuffer.create(replaceSampleBuffer.imageBuffer!,
                                                       replaceSampleBuffer.formatDescription!,
                                                       realSampleBuffer.duration,
                                                       realSampleBuffer.presentationTimeStamp,
                                                       realSampleBuffer.decodeTimeStamp)
        else {
            return nil
        }
        sampleBuffer.isKeyFrame = replaceSampleBuffer.isKeyFrame
        return sampleBuffer
    }
}

final class VideoUnit: NSObject {
    private(set) var device: AVCaptureDevice?
    private var input: AVCaptureInput?
    private var output: AVCaptureVideoDataOutput?
    private var connection: AVCaptureConnection?
    private let context = CIContext()
    private let metalPetalContext: MTIContext?
    weak var drawable: PreviewView?
    var detectionsHistogram = Histogram(name: "Detections", barWidth: 5)
    var filterHistogram = Histogram(name: "Filter", barWidth: 5)
    private var nextFaceDetectionsSequenceNumber: UInt64 = 0
    private var nextCompletedFaceDetectionsSequenceNumber: UInt64 = 0
    private var completedFaceDetections: [UInt64: FaceDetectionsCompletion] = [:]

    var formatDescription: CMVideoFormatDescription? {
        didSet {
            codec.formatDescription = formatDescription
        }
    }

    lazy var codec = VideoCodec(lockQueue: lockQueue)
    weak var mixer: Mixer?
    private var effects: [VideoEffect] = []
    private var pendingAfterAttachEffects: [VideoEffect]?

    var frameRate = Mixer.defaultFrameRate {
        didSet {
            setDeviceFormat(frameRate: frameRate, colorSpace: colorSpace)
        }
    }

    var colorSpace = AVCaptureColorSpace.sRGB {
        didSet {
            setDeviceFormat(frameRate: frameRate, colorSpace: colorSpace)
        }
    }

    var videoOrientation: AVCaptureVideoOrientation = .portrait {
        didSet {
            guard videoOrientation != oldValue else {
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if self.torch, let device = self.device {
                    self.setTorchMode(device, .on)
                }
            }
            for connection in output?.connections.filter({ $0.isVideoOrientationSupported }) ?? [] {
                setOrientation(device: device, connection: connection, orientation: videoOrientation)
            }
        }
    }

    var torch = false {
        didSet {
            guard torch != oldValue, let device = device else {
                return
            }
            setTorchMode(device, torch ? .on : .off)
        }
    }

    private var selectedReplaceVideoCameraId: UUID?
    private var replaceVideos: [UUID: ReplaceVideo] = [:]
    private var blackImageBuffer: CVPixelBuffer?
    private var blackFormatDescription: CMVideoFormatDescription?
    private var blackPixelBufferPool: CVPixelBufferPool?
    private var latestSampleBuffer: CMSampleBuffer?
    private var latestSampleBufferDate: Date?
    private var gapFillerTimer: DispatchSourceTimer?
    private var firstFrameDate: Date?
    private var isFirstAfterAttach = false
    private var latestSampleBufferAppendTime = CMTime.zero
    private var lowFpsImageEnabled: Bool = false
    private var lowFpsImageLatest: Double = 0.0
    private var pool: CVPixelBufferPool?
    private var poolWidth: Int32 = 0
    private var poolHeight: Int32 = 0
    private var poolColorSpace: CGColorSpace?
    private var poolFormatDescriptionExtension: CFDictionary?

    override init() {
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            metalPetalContext = try? MTIContext(device: metalDevice)
        } else {
            metalPetalContext = nil
        }
        super.init()
    }

    deinit {
        stopGapFillerTimer()
    }

    func getHistograms() -> (Histogram, Histogram) {
        return lockQueue.sync {
            (detectionsHistogram, filterHistogram)
        }
    }

    private func startGapFillerTimer() {
        gapFillerTimer = DispatchSource.makeTimerSource(queue: lockQueue)
        let frameInterval = 1 / frameRate
        gapFillerTimer!.schedule(deadline: .now() + frameInterval, repeating: frameInterval)
        gapFillerTimer!.setEventHandler { [weak self] in
            self?.handleGapFillerTimer()
        }
        gapFillerTimer!.activate()
    }

    private func stopGapFillerTimer() {
        gapFillerTimer?.cancel()
        gapFillerTimer = nil
    }

    private func handleGapFillerTimer() {
        guard let latestSampleBufferDate else {
            return
        }
        let delta = Date().timeIntervalSince(latestSampleBufferDate)
        guard delta > 0.05 else {
            return
        }
        guard let latestSampleBuffer else {
            return
        }
        let timeDelta = CMTime(seconds: delta, preferredTimescale: 1000)
        guard let sampleBuffer = CMSampleBuffer.create(latestSampleBuffer.imageBuffer!,
                                                       latestSampleBuffer.formatDescription!,
                                                       latestSampleBuffer.duration,
                                                       latestSampleBuffer.presentationTimeStamp + timeDelta,
                                                       latestSampleBuffer.decodeTimeStamp + timeDelta)
        else {
            return
        }
        guard mixer?
            .useSampleBuffer(sampleBuffer.presentationTimeStamp, mediaType: AVMediaType.video) == true
        else {
            return
        }
        _ = appendSampleBuffer(sampleBuffer, isFirstAfterAttach: false, applyBlur: ioVideoBlurSceneSwitch)
    }

    func attach(_ device: AVCaptureDevice?, _ replaceVideo: UUID?) throws {
        let isOtherReplaceVideo = lockQueue.sync {
            let oldReplaceVideo = self.selectedReplaceVideoCameraId
            self.selectedReplaceVideoCameraId = replaceVideo
            return replaceVideo != oldReplaceVideo
        }
        guard let mixer else {
            return
        }
        if self.device == device {
            if isOtherReplaceVideo {
                lockQueue.async {
                    self.prepareFirstFrame()
                }
            }
            return
        }
        output?.setSampleBufferDelegate(nil, queue: lockQueue)
        let captureSession = mixer.videoSession
        captureSession.beginConfiguration()
        defer {
            captureSession.commitConfiguration()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if self.torch, let device = self.device {
                    self.setTorchMode(device, .on)
                }
            }
        }
        try attachDevice(device, captureSession)
        if device != nil {
            lockQueue.async {
                self.prepareFirstFrame()
            }
        } else {
            lockQueue.async {
                self.stopGapFillerTimer()
            }
        }
        self.device = device
        for connection in output?.connections ?? [] {
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = isVideoMirrored
            }
            if connection.isVideoOrientationSupported {
                setOrientation(device: device, connection: connection, orientation: videoOrientation)
            }
            if connection.isVideoStabilizationSupported {
                connection.preferredVideoStabilizationMode = preferredVideoStabilizationMode
            }
        }
        setDeviceFormat(frameRate: frameRate, colorSpace: colorSpace)
        output?.setSampleBufferDelegate(self, queue: lockQueue)
    }

    private func prepareFirstFrame() {
        firstFrameDate = nil
        isFirstAfterAttach = true
        startGapFillerTimer()
    }

    private func getBufferPool(formatDescription: CMFormatDescription) -> CVPixelBufferPool? {
        let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
        let formatDescriptionExtension = CMFormatDescriptionGetExtensions(formatDescription)
        guard dimensions.width != poolWidth || dimensions
            .height != poolHeight || formatDescriptionExtension != poolFormatDescriptionExtension
        else {
            return pool
        }
        poolWidth = dimensions.width
        poolHeight = dimensions.height
        var pixelBufferAttributes: [NSString: AnyObject] = [
            kCVPixelBufferPixelFormatTypeKey: NSNumber(value: pixelFormatType),
            kCVPixelBufferIOSurfacePropertiesKey: NSDictionary(),
            kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferWidthKey: NSNumber(value: dimensions.width),
            kCVPixelBufferHeightKey: NSNumber(value: dimensions.height),
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

    private func applyEffects(_ imageBuffer: CVImageBuffer,
                              _ sampleBuffer: CMSampleBuffer,
                              _ faceDetections: [VNFaceObservation]?,
                              _ applyBlur: Bool) -> (CVImageBuffer?, CMSampleBuffer?)
    {
        if !ioVideoUnitMetalPetal {
            return applyEffectsCoreImage(imageBuffer, sampleBuffer, faceDetections, applyBlur)
        } else {
            return applyEffectsMetalPetal(imageBuffer, sampleBuffer, faceDetections, applyBlur)
        }
    }

    private func applyEffectsCoreImage(_ imageBuffer: CVImageBuffer,
                                       _ sampleBuffer: CMSampleBuffer,
                                       _ faceDetections: [VNFaceObservation]?,
                                       _ applyBlur: Bool) -> (CVImageBuffer?, CMSampleBuffer?)
    {
        var image = CIImage(cvPixelBuffer: imageBuffer)
        let extent = image.extent
        var failedEffect: String?
        for effect in effects {
            let effectOutputImage = effect.execute(image, faceDetections)
            if effectOutputImage.extent == extent {
                image = effectOutputImage
            } else {
                failedEffect = "\(effect.getName()) (wrong size)"
            }
        }
        mixer?.delegate?.mixerVideo(failedEffect: failedEffect)
        if applyBlur {
            image = blurImage(image)
        }
        guard imageBuffer.width == Int(image.extent.width) && imageBuffer
            .height == Int(image.extent.height)
        else {
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

    // periphery:ignore
    private func brightness(image: MTIImage?) -> MTIImage? {
        let filter = MTIBrightnessFilter()
        filter.inputImage = image
        filter.brightness = 0.0
        return filter.outputImage
    }

    // periphery:ignore
    private func blendWithMask(image: MTIImage?) -> MTIImage? {
        // Not tested.
        let filter = MTIBlendWithMaskFilter()
        filter.inputImage = image
        filter.inputBackgroundImage = nil
        // filter.inputMask = MTIMask(content: RadialGradientImage.makeImage(size: image?.size))
        filter.inputImage = image
        return filter.outputImage
    }

    private func blurImageMetalPetal(_ image: MTIImage?) -> MTIImage? {
        guard let image else {
            return nil
        }
        let filter = MTIMPSGaussianBlurFilter()
        filter.inputImage = image
        filter.radius = Float(25 * (image.extent.height / 1080))
        return filter.outputImage
    }

    private func applyEffectsMetalPetal(_ imageBuffer: CVImageBuffer,
                                        _ sampleBuffer: CMSampleBuffer,
                                        _ faceDetections: [VNFaceObservation]?,
                                        _ applyBlur: Bool) -> (CVImageBuffer?, CMSampleBuffer?)
    {
        let metalPetalEffects = effects.filter { $0.supportsMetalPetal(faceDetections) }
        guard !metalPetalEffects.isEmpty || applyBlur else {
            return (nil, nil)
        }
        var image: MTIImage? = MTIImage(cvPixelBuffer: imageBuffer, alphaType: .alphaIsOne)
        let originalImage = image
        var failedEffect: String?
        for effect in metalPetalEffects {
            let effectOutputImage = effect.executeMetalPetal(image, faceDetections)
            if effectOutputImage != nil {
                image = effectOutputImage
            } else {
                failedEffect = "\(effect.getName()) (wrong size)"
            }
        }
        mixer?.delegate?.mixerVideo(failedEffect: failedEffect)
        if applyBlur {
            image = blurImageMetalPetal(image)
        }
        guard originalImage != image, let image else {
            return (nil, nil)
        }
        guard let outputImageBuffer = createPixelBuffer(sampleBuffer: sampleBuffer) else {
            return (nil, nil)
        }
        do {
            try metalPetalContext?.render(image, to: outputImageBuffer)
        } catch {
            logger.info("Metal petal error: \(error)")
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

    private func blurImage(_ image: CIImage) -> CIImage {
        let filter = CIFilter.gaussianBlur()
        filter.inputImage = image
        filter.radius = Float(25 * (image.extent.height / 1080))
        return filter.outputImage?.cropped(to: image.extent) ?? image
    }

    func registerEffect(_ effect: VideoEffect) {
        lockQueue.sync {
            self.registerEffectInner(effect)
        }
    }

    private func registerEffectInner(_ effect: VideoEffect) {
        if !effects.contains(effect) {
            effects.append(effect)
        }
    }

    func unregisterEffect(_ effect: VideoEffect) {
        lockQueue.sync {
            self.unregisterEffectInner(effect)
        }
    }

    private func unregisterEffectInner(_ effect: VideoEffect) {
        effect.removed()
        if let index = effects.firstIndex(of: effect) {
            effects.remove(at: index)
        }
    }

    func setPendingAfterAttachEffects(effects: [VideoEffect]) {
        lockQueue.sync {
            self.setPendingAfterAttachEffectsInner(effects: effects)
        }
    }

    private func setPendingAfterAttachEffectsInner(effects: [VideoEffect]) {
        pendingAfterAttachEffects = effects
    }

    func usePendingAfterAttachEffects() {
        lockQueue.sync {
            self.usePendingAfterAttachEffectsInner()
        }
    }

    private func usePendingAfterAttachEffectsInner() {
        if let pendingAfterAttachEffects {
            for effect in effects where !pendingAfterAttachEffects.contains(effect) {
                effect.removed()
            }
            effects = pendingAfterAttachEffects
            self.pendingAfterAttachEffects = nil
        }
    }

    func setLowFpsImage(enabled: Bool) {
        lockQueue.sync {
            self.setLowFpsImageInner(enabled: enabled)
        }
    }

    private func setLowFpsImageInner(enabled: Bool) {
        lowFpsImageEnabled = enabled
        lowFpsImageLatest = 0.0
    }

    func addReplaceVideoSampleBuffer(id: UUID, _ sampleBuffer: CMSampleBuffer) {
        lockQueue.async {
            self.addReplaceVideoSampleBufferInner(id: id, sampleBuffer)
        }
    }

    private func addReplaceVideoSampleBufferInner(id: UUID, _ sampleBuffer: CMSampleBuffer) {
        guard let replaceVideo = replaceVideos[id] else {
            return
        }
        replaceVideo.sampleBuffers.append(sampleBuffer)
        replaceVideo.sampleBuffers.sort { sampleBuffer1, sampleBuffer2 in
            sampleBuffer1.presentationTimeStamp < sampleBuffer2.presentationTimeStamp
        }
    }

    func addReplaceVideo(cameraId: UUID, latency: Double) {
        lockQueue.async {
            self.addReplaceVideoInner(cameraId: cameraId, latency: latency)
        }
    }

    private func addReplaceVideoInner(cameraId: UUID, latency: Double) {
        let replaceVideo = ReplaceVideo(latency: latency)
        replaceVideos[cameraId] = replaceVideo
    }

    func removeReplaceVideo(cameraId: UUID) {
        lockQueue.async {
            self.removeReplaceVideoInner(cameraId: cameraId)
        }
    }

    private func removeReplaceVideoInner(cameraId: UUID) {
        replaceVideos.removeValue(forKey: cameraId)
    }

    private func makeBlackSampleBuffer(realSampleBuffer: CMSampleBuffer) -> CMSampleBuffer {
        if blackImageBuffer == nil || blackFormatDescription == nil {
            let width = 1280
            let height = 720
            let pixelBufferAttributes: [NSString: AnyObject] = [
                kCVPixelBufferPixelFormatTypeKey: NSNumber(value: pixelFormatType),
                kCVPixelBufferIOSurfacePropertiesKey: NSDictionary(),
                kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue,
                kCVPixelBufferWidthKey: NSNumber(value: Int(width)),
                kCVPixelBufferHeightKey: NSNumber(value: Int(height)),
            ]
            CVPixelBufferPoolCreate(
                kCFAllocatorDefault,
                nil,
                pixelBufferAttributes as NSDictionary?,
                &blackPixelBufferPool
            )
            guard let blackPixelBufferPool else {
                return realSampleBuffer
            }
            CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, blackPixelBufferPool, &blackImageBuffer)
            guard let blackImageBuffer else {
                return realSampleBuffer
            }
            let image = createBlackImage(width: Double(width), height: Double(height))
            CIContext().render(image, to: blackImageBuffer)
            blackFormatDescription = CMVideoFormatDescription.create(imageBuffer: blackImageBuffer)
            guard blackFormatDescription != nil else {
                return realSampleBuffer
            }
        }
        guard let sampleBuffer = CMSampleBuffer.create(blackImageBuffer!,
                                                       blackFormatDescription!,
                                                       realSampleBuffer.duration,
                                                       realSampleBuffer.presentationTimeStamp,
                                                       realSampleBuffer.decodeTimeStamp)
        else {
            return realSampleBuffer
        }
        return sampleBuffer
    }

    private func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer, isFirstAfterAttach: Bool,
                                    applyBlur: Bool) -> Bool
    {
        guard let imageBuffer = sampleBuffer.imageBuffer else {
            return false
        }
        if sampleBuffer.presentationTimeStamp < latestSampleBufferAppendTime {
            logger.info(
                """
                Discarding frame: \(sampleBuffer.presentationTimeStamp.seconds) \
                \(latestSampleBufferAppendTime.seconds)
                """
            )
            return false
        }
        latestSampleBufferAppendTime = sampleBuffer.presentationTimeStamp
        mixer?.delegate?.mixerVideo(
            presentationTimestamp: sampleBuffer.presentationTimeStamp.seconds
        )
        var completion = FaceDetectionsCompletion(
            sequenceNumber: nextFaceDetectionsSequenceNumber,
            sampleBuffer: sampleBuffer,
            isFirstAfterAttach: isFirstAfterAttach,
            applyBlur: applyBlur
        )
        nextFaceDetectionsSequenceNumber += 1
        if anyEffectNeedsFaceDetections() {
            detectionsQueue.async {
                let startDate = Date()
                let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: imageBuffer)
                let faceLandmarksRequest = VNDetectFaceLandmarksRequest { request, error in
                    lockQueue.async {
                        guard error == nil else {
                            self.faceDetectionsComplete(completion)
                            return
                        }
                        completion.faceDetections = (request as? VNDetectFaceLandmarksRequest)?.results
                        self.faceDetectionsComplete(completion)
                    }
                }
                do {
                    try imageRequestHandler.perform([faceLandmarksRequest])
                } catch {
                    lockQueue.async {
                        self.faceDetectionsComplete(completion)
                    }
                }
                let elapsed = Int(-startDate.timeIntervalSinceNow * 1000)
                lockQueue.async {
                    self.detectionsHistogram.add(value: elapsed)
                }
            }
        } else {
            faceDetectionsComplete(completion)
        }
        return true
    }

    private func faceDetectionsComplete(_ completion: FaceDetectionsCompletion) {
        completedFaceDetections[completion.sequenceNumber] = completion
        while true {
            guard let completion = completedFaceDetections
                .removeValue(forKey: nextCompletedFaceDetectionsSequenceNumber)
            else {
                break
            }
            appendSampleBufferWithFaceDetections(
                completion.sampleBuffer,
                completion.isFirstAfterAttach,
                completion.applyBlur,
                completion.faceDetections
            )
            nextCompletedFaceDetectionsSequenceNumber += 1
        }
    }

    private func appendSampleBufferWithFaceDetections(
        _ sampleBuffer: CMSampleBuffer,
        _ isFirstAfterAttach: Bool,
        _ applyBlur: Bool,
        _ faceDetections: [VNFaceObservation]?
    ) {
        let startDate = Date()
        guard let imageBuffer = sampleBuffer.imageBuffer else {
            return
        }
        var newImageBuffer: CVImageBuffer?
        var newSampleBuffer: CMSampleBuffer?
        if isFirstAfterAttach {
            usePendingAfterAttachEffectsInner()
        }
        if !effects.isEmpty || applyBlur {
            (newImageBuffer, newSampleBuffer) = applyEffects(
                imageBuffer,
                sampleBuffer,
                faceDetections,
                applyBlur
            )
        }
        let modImageBuffer = newImageBuffer ?? imageBuffer
        let modSampleBuffer = newSampleBuffer ?? sampleBuffer
        modSampleBuffer.setAttachmentDisplayImmediately()
        drawable?.enqueue(modSampleBuffer, isFirstAfterAttach: isFirstAfterAttach)
        codec.appendImageBuffer(
            modImageBuffer,
            presentationTimeStamp: modSampleBuffer.presentationTimeStamp,
            duration: modSampleBuffer.duration
        )
        mixer?.recorder.appendVideo(
            modImageBuffer,
            withPresentationTime: modSampleBuffer.presentationTimeStamp
        )
        if lowFpsImageEnabled,
           lowFpsImageLatest + ioVideoUnitWatchInterval < modSampleBuffer.presentationTimeStamp.seconds
        {
            lowFpsImageLatest = modSampleBuffer.presentationTimeStamp.seconds
            lowFpsImageQueue.async {
                self.createLowFpsImage(imageBuffer: modImageBuffer)
            }
        }
        filterHistogram.add(value: Int(-startDate.timeIntervalSinceNow * 1000))
    }

    private func createLowFpsImage(imageBuffer: CVImageBuffer) {
        var ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let scale = 400.0 / Double(imageBuffer.width)
        ciImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let cgImage = context.createCGImage(ciImage, from: ciImage.extent)!
        let image = UIImage(cgImage: cgImage)
        mixer?.delegate?.mixerVideo(lowFpsImage: image.jpegData(compressionQuality: 0.3))
    }

    private func anyEffectNeedsFaceDetections() -> Bool {
        for effect in effects where effect.needsFaceDetections() {
            return true
        }
        return false
    }

    func startEncoding(_ delegate: any AudioCodecDelegate & VideoCodecDelegate) {
        codec.delegate = delegate
        codec.startRunning()
    }

    func stopEncoding() {
        codec.stopRunning()
        codec.delegate = nil
    }

    var isVideoMirrored = false {
        didSet {
            for connection in output?.connections.filter({ $0.isVideoMirroringSupported }) ?? [] {
                connection.isVideoMirrored = isVideoMirrored
            }
        }
    }

    var preferredVideoStabilizationMode: AVCaptureVideoStabilizationMode = .off {
        didSet {
            for connection in output?.connections.filter({ $0.isVideoStabilizationSupported }) ?? [] {
                connection.preferredVideoStabilizationMode = preferredVideoStabilizationMode
            }
        }
    }

    private func setDeviceFormat(frameRate: Float64, colorSpace: AVCaptureColorSpace) {
        guard let device, let mixer else {
            return
        }
        guard let format = device.findVideoFormat(
            width: mixer.sessionPreset.width!,
            height: mixer.sessionPreset.height!,
            frameRate: frameRate,
            colorSpace: colorSpace
        ) else {
            logger.info("No matching video format found")
            return
        }
        logger.debug("Selected video format: \(format)")
        do {
            try device.lockForConfiguration()
            if device.activeFormat != format {
                device.activeFormat = format
            }
            device.activeColorSpace = colorSpace
            device.activeVideoMinFrameDuration = CMTime(
                value: 100,
                timescale: CMTimeScale(100 * frameRate)
            )
            device.activeVideoMaxFrameDuration = CMTime(
                value: 100,
                timescale: CMTimeScale(100 * frameRate)
            )
            device.unlockForConfiguration()
        } catch {
            logger.error("while locking device for fps: \(error)")
        }
    }

    private func attachDevice(_ device: AVCaptureDevice?, _ captureSession: AVCaptureSession) throws {
        if let connection, captureSession.connections.contains(connection) {
            captureSession.removeConnection(connection)
        }
        if let input, captureSession.inputs.contains(input) {
            captureSession.removeInput(input)
        }
        if let output, captureSession.outputs.contains(output) {
            captureSession.removeOutput(output)
        }
        if let device {
            input = try AVCaptureDeviceInput(device: device)
            output = AVCaptureVideoDataOutput()
            output!.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: pixelFormatType,
            ]
            if let port = input?.ports.first(where: { $0.mediaType == .video }) {
                connection = AVCaptureConnection(inputPorts: [port], output: output!)
            } else {
                connection = nil
            }
            if captureSession.canAddInput(input!) {
                captureSession.addInputWithNoConnections(input!)
            }
            if captureSession.canAddOutput(output!) {
                captureSession.addOutputWithNoConnections(output!)
            }
            if let connection, captureSession.canAddConnection(connection) {
                captureSession.addConnection(connection)
            }
            captureSession.automaticallyConfiguresCaptureDeviceForWideColor = false
        } else {
            input = nil
            output = nil
            connection = nil
        }
    }

    private func setTorchMode(_ device: AVCaptureDevice, _ torchMode: AVCaptureDevice.TorchMode) {
        guard device.isTorchModeSupported(torchMode) else {
            return
        }
        do {
            try device.lockForConfiguration()
            device.torchMode = torchMode
            device.unlockForConfiguration()
        } catch {
            logger.error("while setting torch: \(error)")
        }
    }
}

extension VideoUnit: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from _: AVCaptureConnection
    ) {
        for replaceVideo in replaceVideos.values {
            replaceVideo.updateSampleBuffer(sampleBuffer.presentationTimeStamp.seconds)
        }
        var sampleBuffer = sampleBuffer
        if let selectedReplaceVideoCameraId {
            sampleBuffer = replaceVideos[selectedReplaceVideoCameraId]?
                .getSampleBuffer(sampleBuffer) ?? makeBlackSampleBuffer(realSampleBuffer: sampleBuffer)
        }
        let now = Date()
        if firstFrameDate == nil {
            firstFrameDate = now
        }
        guard now.timeIntervalSince(firstFrameDate!) > ioVideoUnitIgnoreFramesAfterAttachSeconds
        else {
            return
        }
        latestSampleBuffer = sampleBuffer
        latestSampleBufferDate = now
        guard mixer?.useSampleBuffer(sampleBuffer.presentationTimeStamp, mediaType: AVMediaType.video) == true
        else {
            return
        }
        if appendSampleBuffer(sampleBuffer, isFirstAfterAttach: isFirstAfterAttach, applyBlur: false) {
            isFirstAfterAttach = false
        }
        stopGapFillerTimer()
    }
}

private func createBlackImage(width: Double, height: Double) -> CIImage {
    UIGraphicsBeginImageContext(CGSize(width: width, height: height))
    let context = UIGraphicsGetCurrentContext()!
    context.setFillColor(UIColor.black.cgColor)
    context.fill([
        CGRect(x: 0, y: 0, width: width, height: height),
    ])
    let image = CIImage(image: UIGraphicsGetImageFromCurrentImageContext()!)!
    UIGraphicsEndImageContext()
    return image
}
