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
var allowVideoRangePixelFormat = false
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
    let rotateDegrees: Int
    let isFirstAfterAttach: Bool
    let applyBlur: Bool
    var faceDetections: [VNFaceObservation]?
}

protocol ReplaceVideoSampleBufferDelegate: AnyObject {
    func didOutputReplaceSampleBuffer(cameraId: UUID, sampleBuffer: CMSampleBuffer)
}

private class ReplaceVideo {
    private var cameraId: UUID
    private var latency: Double
    private var buggedPublisher: Bool
    private var manualFps: Bool
    private var inputFrameRate: Double
    private var outputFrameRate: Double
    private var inputCounter: Int = 0
    private var outputCounter: Int = 0
    private var sampleBufferQueue: [CMSampleBuffer] = []
    private var startTime: Double?
    private var state: State = .initializing
    private var initializationDuration: Double = 1
    private var outputTimer: DispatchSourceTimer?
    private enum State {
        case initializing
        case buffering
        case outputting
    }

    private var maxQueueSize: Int {
        return Int((latency + 5) * inputFrameRate)
    }

    private var minQueueSize: Int {
        return Int(latency * inputFrameRate - 1)
    }

    weak var delegate: ReplaceVideoSampleBufferDelegate?

    init(cameraId: UUID, latency: Double, buggedPublisher: Bool, manualFps: Bool, frameRate: Double) {
        self.cameraId = cameraId
        self.latency = 1 + latency
        self.buggedPublisher = buggedPublisher
        self.manualFps = manualFps
        inputFrameRate = frameRate
        outputFrameRate = 60
    }

    func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer, onSuccess: @escaping (Double) -> Void) {
        let currentTime = CACurrentMediaTime()
        if startTime == nil {
            startTime = currentTime
        }
        sampleBufferQueue.append(sampleBuffer)
        sampleBufferQueue.sort { $0.presentationTimeStamp < $1.presentationTimeStamp }
        inputCounter += 1
        logger.info("ReplaceVideo Queue Count: \(sampleBufferQueue.count)")
        logger.info("Total input frames: \(inputCounter)")
        switch state {
        case .initializing:
            // logger.info("ReplaceVideo initializing.")
            if currentTime - startTime! >= initializationDuration {
                initialize()
                startTime = nil
                state = .buffering
                return
            }
        case .buffering:
            // logger.info("ReplaceVideo buffering.")
            if currentTime - startTime! >= latency {
                state = .outputting
                startOutput()
                onSuccess(inputFrameRate)
            }
        case .outputting:
            // logger.info("ReplaceVideo outputting.")
            balanceQueue()
        }
    }

    var counter: Int = 0
    var firstPresentationTimeStamp: Double?

    private func initialize() {
        if manualFps != true {
            for sampleBuffer in sampleBufferQueue {
                let currentPresentationTime = sampleBuffer.presentationTimeStamp.seconds
                if firstPresentationTimeStamp == nil {
                    firstPresentationTimeStamp = currentPresentationTime
                }
                if let startTime = firstPresentationTimeStamp,
                   currentPresentationTime < startTime + initializationDuration
                {
                    counter += 1
                } else {
                    break
                }
            }
            inputFrameRate = Double(counter) / initializationDuration
            if buggedPublisher == true {
                inputFrameRate = nearestCommonFrameRate(value: inputFrameRate)
            }
        }
        sampleBufferQueue.removeAll()
    }

    private func startOutput() {
        logger.info("ReplaceVideo latency: \(latency)")
        logger.info("ReplaceVideo frameRate: \(inputFrameRate)")
        outputTimer = DispatchSource.makeTimerSource(queue: lockQueue)
        outputTimer?.schedule(deadline: .now(), repeating: 1 / outputFrameRate)
        outputTimer?.setEventHandler { [weak self] in
            self?.output()
        }
        outputTimer?.activate()
    }

    private func output() {
        guard let sampleBuffer = getNextSampleBuffer() else {
            logger.info("ReplaceVideo Queue size low. Waiting for more sampleBuffers.")
            return
        }
        let presentationTimeStamp = CMClockGetTime(CMClockGetHostTimeClock())
        guard let sampleBuffer = sampleBuffer
            .replacePresentationTimeStamp(presentationTimeStamp: presentationTimeStamp)
        else {
            return
        }
        delegate?.didOutputReplaceSampleBuffer(cameraId: cameraId, sampleBuffer: sampleBuffer)
        outputCounter += 1
        logger.info("Total output frames: \(outputCounter)")
    }

    var numDuplicates: Double = 0

    private func getNextSampleBuffer() -> CMSampleBuffer? {
        if sampleBufferQueue.isEmpty {
            return nil
        }

        let ratio = outputFrameRate / inputFrameRate

        if inputFrameRate < outputFrameRate {
            // Duplicate frames
            if numDuplicates == 0 {
                numDuplicates = ratio - 1
            }
            if numDuplicates >= 1 {
                numDuplicates -= 1
                return sampleBufferQueue.first
            } else {
                numDuplicates += ratio - 1
            }
        }
//        else {
//            // Drop frames
//            let numToDrop = Int(inputFrameRate / outputFrameRate)
//            if numToDrop > 1 {
//                for _ in 0..<(numToDrop - 1) {
//                    if sampleBufferQueue.isEmpty {
//                        return nil
//                    }
//                    sampleBufferQueue.removeFirst()
//                }
//            }
//        }
        return sampleBufferQueue.removeFirst()
    }

    private func balanceQueue() {
        if sampleBufferQueue.count > maxQueueSize {
            logger.info("ReplaceVideo Queue size high. Drop oldest sampleBuffer.")
            sampleBufferQueue.removeFirst()
        }
        // if sampleBufferQueue.count < minQueueSize {
        //     logger.info("ReplaceVideo Queue size low. Duplicate oldest sampleBuffer.")
        //     sampleBufferQueue.insert(sampleBufferQueue.first!, at: 0)
        // }
    }

    func stopOutput() {
        outputTimer?.cancel()
        outputTimer = nil
        sampleBufferQueue.removeAll()
        startTime = nil
        counter = 0
        firstPresentationTimeStamp = nil
        state = .initializing
    }

    func nearestCommonFrameRate(value: Double) -> Double {
        let commonFrameRates = [25.0, 30.0, 50.0, 60.0]
        return commonFrameRates.min(by: { abs($0 - value) < abs($1 - value) })!
    }
}

final class VideoUnit: NSObject {
    static let defaultFrameRate: Float64 = 30
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
    var preset: AVCaptureSession.Preset = .hd1280x720
    let session = makeCaptureSession()

    var formatDescription: CMVideoFormatDescription? {
        didSet {
            codec.formatDescription = formatDescription
        }
    }

    lazy var codec = VideoCodec(lockQueue: lockQueue)
    weak var mixer: Mixer?
    private var effects: [VideoEffect] = []
    private var pendingAfterAttachEffects: [VideoEffect]?

    var frameRate = VideoUnit.defaultFrameRate {
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
            for connection in output?.connections.filter({ $0.isVideoOrientationSupported }) ?? [] {
                setOrientation(device: device, connection: connection, orientation: videoOrientation)
            }
        }
    }

    var torch = false {
        didSet {
            guard let device else {
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
    private var frameTimer: DispatchSourceTimer?
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
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleSessionRuntimeError),
                                               name: .AVCaptureSessionRuntimeError,
                                               object: session)
    }

    deinit {
        stopFrameTimer()
    }

    @objc
    private func handleSessionRuntimeError(_ notification: NSNotification) {
        logger.error("Video session error: \(notification)")
    }

    func startRunning() {
        session.startRunning()
    }

    func stopRunning() {
        removeSessionObservers()
        session.stopRunning()
    }

    func getHistograms() -> (Histogram, Histogram) {
        return lockQueue.sync {
            (detectionsHistogram, filterHistogram)
        }
    }

    private func startFrameTimer() {
        let frameInterval = 1 / frameRate
        frameTimer = DispatchSource.makeTimerSource(queue: lockQueue)
        frameTimer!.schedule(deadline: .now() + frameInterval, repeating: frameInterval)
        frameTimer!.setEventHandler { [weak self] in
            self?.handleGapFillerTimer()
            self?.handleBlackImageTimer()
        }
        frameTimer!.activate()
    }

    private func stopFrameTimer() {
        frameTimer?.cancel()
        frameTimer = nil
    }

    private func handleGapFillerTimer() {
        guard selectedReplaceVideoCameraId == nil else {
            return
        }
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
        _ = appendSampleBuffer(
            sampleBuffer,
            rotateDegrees: 0,
            isFirstAfterAttach: false,
            applyBlur: ioVideoBlurSceneSwitch
        )
    }

    private func handleBlackImageTimer() {
        guard selectedReplaceVideoCameraId != nil else {
            return
        }
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
        let sampleBuffer = makeBlackSampleBuffer(realSampleBuffer: latestSampleBuffer, timeDelta: timeDelta)
        guard mixer?
            .useSampleBuffer(sampleBuffer.presentationTimeStamp, mediaType: AVMediaType.video) == true
        else {
            return
        }
        _ = appendSampleBuffer(
            sampleBuffer,
            rotateDegrees: 0,
            isFirstAfterAttach: false,
            applyBlur: ioVideoBlurSceneSwitch
        )
    }

    func attach(_ device: AVCaptureDevice?, _ replaceVideo: UUID?) throws {
        let isOtherReplaceVideo = lockQueue.sync {
            let oldReplaceVideo = self.selectedReplaceVideoCameraId
            self.selectedReplaceVideoCameraId = replaceVideo
            return replaceVideo != oldReplaceVideo
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
        session.beginConfiguration()
        defer {
            session.commitConfiguration()
        }
        try attachDevice(device, session)
        if device != nil {
            lockQueue.async {
                self.prepareFirstFrame()
            }
        } else {
            lockQueue.async {
                self.stopFrameTimer()
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
        startFrameTimer()
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
                              _ rotateDegrees: Int,
                              _ faceDetections: [VNFaceObservation]?,
                              _ applyBlur: Bool,
                              _ isFirstAfterAttach: Bool) -> (CVImageBuffer?, CMSampleBuffer?)
    {
        if #available(iOS 17.2, *), colorSpace == .appleLog || !ioVideoUnitMetalPetal {
            return applyEffectsCoreImage(
                imageBuffer,
                sampleBuffer,
                rotateDegrees,
                faceDetections,
                applyBlur,
                isFirstAfterAttach
            )
        } else {
            return applyEffectsMetalPetal(
                imageBuffer,
                sampleBuffer,
                rotateDegrees,
                faceDetections,
                applyBlur,
                isFirstAfterAttach
            )
        }
    }

    private func applyEffectsCoreImage(_ imageBuffer: CVImageBuffer,
                                       _ sampleBuffer: CMSampleBuffer,
                                       _: Int,
                                       _ faceDetections: [VNFaceObservation]?,
                                       _ applyBlur: Bool,
                                       _ isFirstAfterAttach: Bool) -> (CVImageBuffer?, CMSampleBuffer?)
    {
        var image = CIImage(cvPixelBuffer: imageBuffer)
        let extent = image.extent
        var failedEffect: String?
        for effect in effects {
            let effectOutputImage = effect.execute(image, faceDetections, isFirstAfterAttach)
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

    private func rotateImageMetalPetal(_ image: MTIImage?, _ rotateDegrees: Int) -> MTIImage? {
        if rotateDegrees == 90 {
            return image?.oriented(.left)
        } else {
            return image
        }
    }

    // periphery:ignore
    private func scaleImageMetalPetal(_ image: MTIImage?) -> MTIImage? {
        guard let image else {
            return image
        }
        let filter = MTIMultilayerCompositingFilter()
        filter.inputBackgroundImage = MTIImage(
            color: .black,
            sRGB: false,
            size: .init(width: CGFloat(preset.width!), height: CGFloat(preset.height!))
        )
        filter.layers = [
            .init(
                content: image,
                position: .init(x: CGFloat(preset.width! / 2), y: CGFloat(preset.height! / 2))
            ),
        ]
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
                                        _ rotateDegrees: Int,
                                        _ faceDetections: [VNFaceObservation]?,
                                        _ applyBlur: Bool,
                                        _ isFirstAfterAttach: Bool) -> (CVImageBuffer?, CMSampleBuffer?)
    {
        var image: MTIImage? = MTIImage(cvPixelBuffer: imageBuffer, alphaType: .alphaIsOne)
        let originalImage = image
        var failedEffect: String?
        if rotateDegrees != 0 {
            image = rotateImageMetalPetal(image, rotateDegrees)
        }
        // if let image2 = image,
        //    Int32(image2.size.width) != preset.width! || Int32(image2.size.height) != preset.height!
        // {
        //    image = scaleImageMetalPetal(image)
        // }
        for effect in effects {
            let effectOutputImage = effect.executeMetalPetal(image, faceDetections, isFirstAfterAttach)
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

    func addReplaceVideoSampleBuffer(
        id: UUID,
        _ sampleBuffer: CMSampleBuffer,
        onSuccess: @escaping (Double) -> Void
    ) {
        lockQueue.async {
            self.addReplaceVideoSampleBufferInner(id: id, sampleBuffer, onSuccess: onSuccess)
        }
    }

    private func addReplaceVideoSampleBufferInner(
        id: UUID,
        _ sampleBuffer: CMSampleBuffer,
        onSuccess: @escaping (Double) -> Void
    ) {
        guard let replaceVideo = replaceVideos[id] else {
            return
        }
        replaceVideo.appendSampleBuffer(sampleBuffer, onSuccess: onSuccess)
    }

    func addReplaceVideo(
        cameraId: UUID,
        latency: Double,
        buggedPublisher: Bool,
        manualFps: Bool,
        frameRate: Double
    ) {
        lockQueue.async {
            self.addReplaceVideoInner(
                cameraId: cameraId,
                latency: latency,
                buggedPublisher: buggedPublisher,
                manualFps: manualFps,
                frameRate: frameRate
            )
        }
    }

    private func addReplaceVideoInner(
        cameraId: UUID,
        latency: Double,
        buggedPublisher: Bool,
        manualFps: Bool,
        frameRate: Double
    ) {
        let replaceVideo = ReplaceVideo(
            cameraId: cameraId,
            latency: latency,
            buggedPublisher: buggedPublisher,
            manualFps: manualFps,
            frameRate: frameRate
        )
        replaceVideo.delegate = self
        replaceVideos[cameraId] = replaceVideo
    }

    func removeReplaceVideo(cameraId: UUID) {
        lockQueue.async {
            self.removeReplaceVideoInner(cameraId: cameraId)
        }
    }

    private func removeReplaceVideoInner(cameraId: UUID) {
        let replaceVideo = replaceVideos[cameraId]
        replaceVideo?.stopOutput()
        replaceVideos.removeValue(forKey: cameraId)
    }

    private func makeBlackSampleBuffer(realSampleBuffer: CMSampleBuffer,
                                       timeDelta: CMTime) -> CMSampleBuffer
    {
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
                                                       realSampleBuffer.presentationTimeStamp + timeDelta,
                                                       realSampleBuffer.decodeTimeStamp + timeDelta)
        else {
            return realSampleBuffer
        }
        return sampleBuffer
    }

    private func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer,
                                    rotateDegrees: Int,
                                    isFirstAfterAttach: Bool,
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
            rotateDegrees: rotateDegrees,
            isFirstAfterAttach: isFirstAfterAttach,
            applyBlur: applyBlur
        )
        nextFaceDetectionsSequenceNumber += 1
        if anyEffectNeedsFaceDetections() {
            detectionsQueue.async {
                let startTime = ContinuousClock.now
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
                let elapsed = Int(startTime.duration(to: .now).milliseconds)
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
        while let completion = completedFaceDetections
            .removeValue(forKey: nextCompletedFaceDetectionsSequenceNumber)
        {
            appendSampleBufferWithFaceDetections(
                completion.sampleBuffer,
                completion.rotateDegrees,
                completion.isFirstAfterAttach,
                completion.applyBlur,
                completion.faceDetections
            )
            nextCompletedFaceDetectionsSequenceNumber += 1
        }
    }

    private func appendSampleBufferWithFaceDetections(
        _ sampleBuffer: CMSampleBuffer,
        _ rotateDegrees: Int,
        _ isFirstAfterAttach: Bool,
        _ applyBlur: Bool,
        _ faceDetections: [VNFaceObservation]?
    ) {
        let startTime = ContinuousClock.now
        guard let imageBuffer = sampleBuffer.imageBuffer else {
            return
        }
        var newImageBuffer: CVImageBuffer?
        var newSampleBuffer: CMSampleBuffer?
        if isFirstAfterAttach {
            usePendingAfterAttachEffectsInner()
        }
        if !effects.isEmpty || applyBlur || rotateDegrees != 0 {
            (newImageBuffer, newSampleBuffer) = applyEffects(
                imageBuffer,
                sampleBuffer,
                rotateDegrees,
                faceDetections,
                applyBlur,
                isFirstAfterAttach
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
        filterHistogram.add(value: Int(startTime.duration(to: .now).milliseconds))
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
        addSessionObservers()
        codec.delegate = delegate
        codec.startRunning()
    }

    func stopEncoding() {
        codec.stopRunning()
        codec.delegate = nil
        removeSessionObservers()
    }

    private func addSessionObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionWasInterrupted),
            name: .AVCaptureSessionWasInterrupted,
            object: session
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionInterruptionEnded),
            name: .AVCaptureSessionInterruptionEnded,
            object: session
        )
    }

    private func removeSessionObservers() {
        NotificationCenter.default.removeObserver(
            self,
            name: .AVCaptureSessionWasInterrupted,
            object: session
        )
        NotificationCenter.default.removeObserver(
            self,
            name: .AVCaptureSessionInterruptionEnded,
            object: session
        )
    }

    @objc
    private func sessionWasInterrupted(_: Notification) {
        logger.info("Video session interruption started")
        lockQueue.async {
            self.prepareFirstFrame()
        }
    }

    @objc
    private func sessionInterruptionEnded(_: Notification) {
        logger.info("Video session interruption ended")
    }

    var isVideoMirrored = false

    var preferredVideoStabilizationMode: AVCaptureVideoStabilizationMode = .off {
        didSet {
            for connection in output?.connections.filter({ $0.isVideoStabilizationSupported }) ?? [] {
                connection.preferredVideoStabilizationMode = preferredVideoStabilizationMode
            }
        }
    }

    private func findVideoFormat(
        device: AVCaptureDevice,
        width: Int32,
        height: Int32,
        frameRate: Float64,
        colorSpace: AVCaptureColorSpace
    ) -> (AVCaptureDevice.Format?, String?) {
        var formats = device.formats
            .filter { $0.isFrameRateSupported(frameRate) }
            .filter { $0.formatDescription.dimensions.width == width }
            .filter { $0.formatDescription.dimensions.height == height }
            .filter { $0.supportedColorSpaces.contains(colorSpace) }
        if formats.isEmpty {
            return (nil, "No video format found matching \(height)p\(Int(frameRate)), \(colorSpace)")
        }
        formats = formats.filter { !$0.isVideoBinned }
        if formats.isEmpty {
            return (nil, "No unbinned video format found")
        }
        // 420v does not work with OA4.
        formats = formats.filter {
            $0.formatDescription.mediaSubType
                .rawValue != kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange || allowVideoRangePixelFormat
        }
        if formats.isEmpty {
            return (nil, "Unsupported video pixel format")
        }
        return (formats.first, nil)
    }

    private func reportFormatNotFound(_ device: AVCaptureDevice, _ error: String) {
        let (minFps, maxFps) = device.fps
        let activeFormat = """
        Using default: \
        \(device.activeFormat.formatDescription.dimensions.height)p, \
        \(minFps)-\(maxFps) FPS, \
        \(device.activeColorSpace), \
        \(device.activeFormat.formatDescription.mediaSubType)
        """
        logger.info(error)
        logger.info(activeFormat)
        mixer?.delegate?.mixer(findVideoFormatError: error, activeFormat: activeFormat)
        for format in device.formats {
            logger.info("Available video format: \(format)")
        }
    }

    private func setDeviceFormat(frameRate: Float64, colorSpace: AVCaptureColorSpace) {
        guard let device else {
            return
        }
        let (format, error) = findVideoFormat(
            device: device,
            width: preset.width!,
            height: preset.height!,
            frameRate: frameRate,
            colorSpace: colorSpace
        )
        if let error {
            reportFormatNotFound(device, error)
            return
        }
        guard let format else {
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

    func prepareSampleBuffer(sampleBuffer: CMSampleBuffer) {
        let rotateDegrees = 0
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
        if appendSampleBuffer(
            sampleBuffer,
            rotateDegrees: rotateDegrees,
            isFirstAfterAttach: isFirstAfterAttach,
            applyBlur: false
        ) {
            isFirstAfterAttach = false
        }
        stopFrameTimer()
    }
}

extension VideoUnit: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from _: AVCaptureConnection
    ) {
        guard selectedReplaceVideoCameraId == nil else {
            return
        }
        prepareSampleBuffer(sampleBuffer: sampleBuffer)
    }
}

extension VideoUnit: ReplaceVideoSampleBufferDelegate {
    func didOutputReplaceSampleBuffer(cameraId: UUID, sampleBuffer: CMSampleBuffer) {
        if cameraId == selectedReplaceVideoCameraId {
            prepareSampleBuffer(sampleBuffer: sampleBuffer)
        }
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
