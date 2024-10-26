import AVFoundation
import Collections
import CoreImage
import MetalPetal
import UIKit
import Vision

var ioVideoBlurSceneSwitch = true
var ioVideoUnitIgnoreFramesAfterAttachSeconds = 0.3
var pixelFormatType = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
var ioVideoUnitMetalPetal = false
var allowVideoRangePixelFormat = false
private let lockQueue = DispatchQueue(
    label: "com.haishinkit.HaishinKit.VideoIOComponent",
    qos: .userInteractive
)
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
    // periphery:ignore
    let sequenceNumber: UInt64
    let sampleBuffer: CMSampleBuffer
    let isFirstAfterAttach: Bool
    let applyBlur: Bool
    var faceDetections: [VNFaceObservation]?
}

private class ReplaceVideo {
    private var sampleBuffers: Deque<CMSampleBuffer> = []
    private var currentSampleBuffer: CMSampleBuffer?
    private var timeOffset = 0.0
    private let name: String
    private let update: Bool

    init(name: String, update: Bool) {
        self.name = name
        self.update = update
    }

    func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        if let index = sampleBuffers
            .lastIndex(where: { $0.presentationTimeStamp < sampleBuffer.presentationTimeStamp })
        {
            sampleBuffers.insert(sampleBuffer, at: sampleBuffers.index(after: index))
        } else {
            sampleBuffers.append(sampleBuffer)
        }
    }

    func updateSampleBuffer(_ outputPresentationTimeStamp: Double) {
        guard update else {
            return
        }
        var numberOfBuffersConsumed = 0
        while let inputSampleBuffer = sampleBuffers.first {
            if currentSampleBuffer == nil {
                currentSampleBuffer = inputSampleBuffer
            }
            if sampleBuffers.count > 200 {
                logger.info("""
                replace-video: \(name): Over 200 frames (\(sampleBuffers.count)) buffered. Dropping \
                oldest frame.
                """)
                currentSampleBuffer = inputSampleBuffer
                sampleBuffers.removeFirst()
                numberOfBuffersConsumed += 1
                continue
            }
            let inputPresentationTimeStamp = inputSampleBuffer.presentationTimeStamp.seconds
            let inputOutputDelta = inputPresentationTimeStamp - outputPresentationTimeStamp + timeOffset
            if abs(inputOutputDelta) < 0.002 {
                logger.debug("replace-video: \(name): Small delta. Swap offset from \(timeOffset).")
                if timeOffset == 0.0 {
                    timeOffset = 0.01
                } else {
                    timeOffset = 0.0
                }
            }
            // Break on first frame that is ahead in time.
            if inputOutputDelta > 0 {
                break
            }
            currentSampleBuffer = inputSampleBuffer
            sampleBuffers.removeFirst()
            numberOfBuffersConsumed += 1
        }
        if logger.debugEnabled {
            if numberOfBuffersConsumed == 0 {
                logger.debug("""
                replace-video: \(name): Duplicating buffer. \
                Output time \(outputPresentationTimeStamp) \
                Current \(currentSampleBuffer?.presentationTimeStamp.seconds ?? .nan). \
                Buffers count is \(sampleBuffers.count). \
                First \(sampleBuffers.first?.presentationTimeStamp.seconds ?? .nan). \
                Last \(sampleBuffers.last?.presentationTimeStamp.seconds ?? .nan).
                """)
            } else if numberOfBuffersConsumed > 1 {
                logger.debug("""
                replace-video: \(name): Dropping \(numberOfBuffersConsumed - 1) buffer(s). \
                Output time \(outputPresentationTimeStamp) \
                Current \(currentSampleBuffer?.presentationTimeStamp.seconds ?? .nan). \
                Buffers count is \(sampleBuffers.count). \
                First \(sampleBuffers.first?.presentationTimeStamp.seconds ?? .nan). \
                Last \(sampleBuffers.last?.presentationTimeStamp.seconds ?? .nan).
                """)
            }
        }
    }

    func setLatestSampleBuffer(sampleBuffer: CMSampleBuffer?) {
        currentSampleBuffer = sampleBuffer
    }

    func getSampleBuffer(_ presentationTimeStamp: CMTime) -> CMSampleBuffer? {
        return currentSampleBuffer?.replacePresentationTimeStamp(presentationTimeStamp)
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
    private var nextFaceDetectionsSequenceNumber: UInt64 = 0
    private var nextCompletedFaceDetectionsSequenceNumber: UInt64 = 0
    private var completedFaceDetections: [UInt64: FaceDetectionsCompletion] = [:]
    var captureSize = CGSize(width: 1920, height: 1080)
    var outputSize = CGSize(width: 1920, height: 1080)
    let session = makeCaptureSession()

    var formatDescription: CMVideoFormatDescription? {
        didSet {
            encoder.formatDescription = formatDescription
        }
    }

    lazy var encoder = VideoCodec(lockQueue: lockQueue)
    weak var mixer: Mixer?
    private var effects: [VideoEffect] = []
    private var pendingAfterAttachEffects: [VideoEffect]?

    var frameRate = VideoUnit.defaultFrameRate {
        didSet {
            setDeviceFormat(frameRate: frameRate, colorSpace: colorSpace)
            startFrameTimer()
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
                if torch {
                    mixer?.delegate?.mixerNoTorch()
                }
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
    private var latestSampleBufferTime: ContinuousClock.Instant?
    private var frameTimer: DispatchSourceTimer?
    private var firstFrameTime: ContinuousClock.Instant?
    private var isFirstAfterAttach = false
    private var latestSampleBufferAppendTime = CMTime.zero
    private var lowFpsImageEnabled: Bool = false
    private var lowFpsImageInterval: Double = 1.0
    private var lowFpsImageLatest: Double = 0.0
    private var lowFpsImageFrameNumber: UInt64 = 0
    private var takeSnapshotComplete: ((UIImage) -> Void)?
    private var pool: CVPixelBufferPool?
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
        replaceVideos[builtinCameraId] = ReplaceVideo(name: "Builtin", update: false)
        startFrameTimer()
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

    func getCIImage(_ videoSourceId: UUID, _ presentationTimeStamp: CMTime) -> CIImage? {
        guard let sampleBuffer = replaceVideos[videoSourceId]?.getSampleBuffer(presentationTimeStamp) else {
            return nil
        }
        guard let imageBuffer = sampleBuffer.imageBuffer else {
            return nil
        }
        return CIImage(cvPixelBuffer: imageBuffer)
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
        lockQueue.async {
            self.prepareFirstFrame()
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

    func registerEffect(_ effect: VideoEffect) {
        lockQueue.sync {
            self.registerEffectInner(effect)
        }
    }

    func unregisterEffect(_ effect: VideoEffect) {
        lockQueue.sync {
            self.unregisterEffectInner(effect)
        }
    }

    func setPendingAfterAttachEffects(effects: [VideoEffect]) {
        lockQueue.sync {
            self.setPendingAfterAttachEffectsInner(effects: effects)
        }
    }

    func usePendingAfterAttachEffects() {
        lockQueue.sync {
            self.usePendingAfterAttachEffectsInner()
        }
    }

    func setLowFpsImage(fps: Float) {
        lockQueue.async {
            self.setLowFpsImageInner(fps: fps)
        }
    }

    func takeSnapshot(onComplete: @escaping (UIImage) -> Void) {
        lockQueue.async {
            self.takeSnapshotComplete = onComplete
        }
    }

    func addReplaceVideoSampleBuffer(id: UUID, _ sampleBuffer: CMSampleBuffer) {
        lockQueue.async {
            self.addReplaceVideoSampleBufferInner(id: id, sampleBuffer)
        }
    }

    func addReplaceVideo(cameraId: UUID, name: String) {
        lockQueue.async {
            self.addReplaceVideoInner(cameraId: cameraId, name: name)
        }
    }

    func removeReplaceVideo(cameraId: UUID) {
        lockQueue.async {
            self.removeReplaceVideoInner(cameraId: cameraId)
        }
    }

    func startEncoding(_ delegate: any AudioCodecDelegate & VideoCodecDelegate) {
        addSessionObservers()
        encoder.delegate = delegate
        encoder.startRunning()
    }

    func stopEncoding() {
        encoder.stopRunning()
        encoder.delegate = nil
        removeSessionObservers()
    }

    private func startFrameTimer() {
        let frameInterval = 1 / frameRate
        frameTimer = DispatchSource.makeTimerSource(queue: lockQueue)
        frameTimer!.schedule(deadline: .now() + frameInterval, repeating: frameInterval)
        frameTimer!.setEventHandler { [weak self] in
            self?.handleFrameTimer()
        }
        frameTimer!.activate()
    }

    private func stopFrameTimer() {
        frameTimer?.cancel()
        frameTimer = nil
    }

    private func handleFrameTimer() {
        let presentationTimeStamp = currentPresentationTimeStamp()
        handleReplaceVideo(presentationTimeStamp)
        handleGapFillerTimer()
    }

    private func handleReplaceVideo(_ presentationTimeStamp: CMTime) {
        for replaceVideo in replaceVideos.values {
            replaceVideo.updateSampleBuffer(presentationTimeStamp.seconds)
        }
        guard let selectedReplaceVideoCameraId else {
            return
        }
        if let sampleBuffer = replaceVideos[selectedReplaceVideoCameraId]?
            .getSampleBuffer(presentationTimeStamp)
        {
            appendNewSampleBuffer(sampleBuffer: sampleBuffer)
        } else if let sampleBuffer = makeBlackSampleBuffer(
            duration: .invalid,
            presentationTimeStamp: presentationTimeStamp,
            decodeTimeStamp: .invalid
        ) {
            appendNewSampleBuffer(sampleBuffer: sampleBuffer)
        } else {
            logger.info("replace-video: Failed to output frame")
        }
    }

    private func handleGapFillerTimer() {
        guard isFirstAfterAttach else {
            return
        }
        guard let latestSampleBuffer, let latestSampleBufferTime else {
            return
        }
        let delta = latestSampleBufferTime.duration(to: .now)
        guard delta > .seconds(0.05) else {
            return
        }
        let timeDelta = CMTime(seconds: delta.seconds, preferredTimescale: 1000)
        guard let sampleBuffer = CMSampleBuffer.create(latestSampleBuffer.imageBuffer!,
                                                       latestSampleBuffer.formatDescription!,
                                                       latestSampleBuffer.duration,
                                                       latestSampleBuffer.presentationTimeStamp + timeDelta,
                                                       latestSampleBuffer.decodeTimeStamp + timeDelta)
        else {
            return
        }
        _ = appendSampleBuffer(
            sampleBuffer,
            isFirstAfterAttach: false,
            applyBlur: ioVideoBlurSceneSwitch
        )
    }

    private func prepareFirstFrame() {
        firstFrameTime = nil
        isFirstAfterAttach = true
    }

    private func getBufferPool(formatDescription: CMFormatDescription) -> CVPixelBufferPool? {
        let formatDescriptionExtension = CMFormatDescriptionGetExtensions(formatDescription)
        if let pool, formatDescriptionExtension == poolFormatDescriptionExtension {
            return pool
        }
        var pixelBufferAttributes: [NSString: AnyObject] = [
            kCVPixelBufferPixelFormatTypeKey: NSNumber(value: pixelFormatType),
            kCVPixelBufferIOSurfacePropertiesKey: NSDictionary(),
            kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferWidthKey: NSNumber(value: outputSize.width),
            kCVPixelBufferHeightKey: NSNumber(value: outputSize.height),
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
                              _ applyBlur: Bool,
                              _ isFirstAfterAttach: Bool) -> (CVImageBuffer?, CMSampleBuffer?)
    {
        let info = VideoEffectInfo(
            isFirstAfterAttach: isFirstAfterAttach,
            faceDetections: faceDetections,
            presentationTimeStamp: sampleBuffer.presentationTimeStamp,
            videoUnit: self
        )
        if #available(iOS 17.2, *), colorSpace == .appleLog {
            return applyEffectsCoreImage(
                imageBuffer,
                sampleBuffer,
                applyBlur,
                info
            )
        } else if ioVideoUnitMetalPetal {
            return applyEffectsMetalPetal(
                imageBuffer,
                sampleBuffer,
                applyBlur,
                info
            )
        } else {
            return applyEffectsCoreImage(
                imageBuffer,
                sampleBuffer,
                applyBlur,
                info
            )
        }
    }

    private func removeEffects() {
        var effectsToRemove: [VideoEffect] = []
        for effect in effects where effect.shouldRemove() {
            effectsToRemove.append(effect)
        }
        for effect in effectsToRemove {
            unregisterEffectInner(effect)
        }
    }

    private var blackImage: CIImage?

    private func getBlackImage(width: Double, height: Double) -> CIImage {
        if blackImage == nil {
            blackImage = createBlackImage(width: width, height: height)
        }
        return blackImage!
    }

    private func scaleImage(_ image: CIImage) -> CIImage {
        let imageRatio = image.extent.height / image.extent.width
        let outputRatio = outputSize.height / outputSize.width
        var scaleFactor: Double
        var x: Double
        var y: Double
        if outputRatio > imageRatio {
            scaleFactor = Double(outputSize.width) / image.extent.width
            x = 0
            y = (Double(outputSize.height) - image.extent.height * scaleFactor) / 2
        } else {
            scaleFactor = Double(outputSize.height) / image.extent.height
            x = (Double(outputSize.width) - image.extent.width * scaleFactor) / 2
            y = 0
        }
        return image
            .transformed(by: CGAffineTransform(scaleX: scaleFactor, y: scaleFactor))
            .transformed(by: CGAffineTransform(translationX: x, y: y))
            .composited(over: getBlackImage(
                width: Double(outputSize.width),
                height: Double(outputSize.height)
            ))
    }

    private func applyEffectsCoreImage(_ imageBuffer: CVImageBuffer,
                                       _ sampleBuffer: CMSampleBuffer,
                                       _ applyBlur: Bool,
                                       _ info: VideoEffectInfo) -> (CVImageBuffer?, CMSampleBuffer?)
    {
        var image = CIImage(cvPixelBuffer: imageBuffer)
        if imageBuffer.isPortrait() {
            image = image.oriented(.left)
        }
        if image.extent.size != outputSize {
            image = scaleImage(image)
        }
        let extent = image.extent
        var failedEffect: String?
        if applyBlur {
            image = blurImage(image)
        }
        for effect in effects {
            let effectOutputImage = effect.execute(image, info)
            if effectOutputImage.extent == extent {
                image = effectOutputImage
            } else {
                failedEffect = "\(effect.getName()) (wrong size)"
            }
        }
        mixer?.delegate?.mixerVideo(failedEffect: failedEffect)
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

    private func scaleImageMetalPetal(_ image: MTIImage?) -> MTIImage? {
        guard let image = image?.resized(
            to: CGSize(width: Double(outputSize.width), height: Double(outputSize.height)),
            resizingMode: .aspect
        ) else {
            return image
        }
        let filter = MTIMultilayerCompositingFilter()
        filter.inputBackgroundImage = MTIImage(
            color: .black,
            sRGB: false,
            size: .init(width: CGFloat(outputSize.width), height: CGFloat(outputSize.height))
        )
        filter.layers = [
            .init(
                content: image,
                position: .init(x: CGFloat(outputSize.width / 2), y: CGFloat(outputSize.height / 2))
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
                                        _ applyBlur: Bool,
                                        _ info: VideoEffectInfo) -> (CVImageBuffer?, CMSampleBuffer?)
    {
        var image: MTIImage? = MTIImage(cvPixelBuffer: imageBuffer, alphaType: .alphaIsOne)
        let originalImage = image
        var failedEffect: String?
        if imageBuffer.isPortrait() {
            image = image?.oriented(.left)
        }
        if let imageToScale = image, imageToScale.size != outputSize {
            image = scaleImageMetalPetal(image)
        }
        if applyBlur {
            image = blurImageMetalPetal(image)
        }
        for effect in effects {
            let effectOutputImage = effect.executeMetalPetal(image, info)
            if effectOutputImage != nil {
                image = effectOutputImage
            } else {
                failedEffect = "\(effect.getName()) (wrong size)"
            }
        }
        mixer?.delegate?.mixerVideo(failedEffect: failedEffect)
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

    private func registerEffectInner(_ effect: VideoEffect) {
        if !effects.contains(effect) {
            effects.append(effect)
        }
    }

    private func unregisterEffectInner(_ effect: VideoEffect) {
        effect.removed()
        if let index = effects.firstIndex(of: effect) {
            effects.remove(at: index)
        }
    }

    private func setPendingAfterAttachEffectsInner(effects: [VideoEffect]) {
        pendingAfterAttachEffects = effects
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

    private func setLowFpsImageInner(fps: Float) {
        lowFpsImageInterval = Double(1 / fps).clamped(to: 0.2 ... 1.0)
        lowFpsImageEnabled = fps != 0.0
        lowFpsImageLatest = 0.0
    }

    private func addReplaceVideoSampleBufferInner(id: UUID, _ sampleBuffer: CMSampleBuffer) {
        guard let replaceVideo = replaceVideos[id] else {
            return
        }
        replaceVideo.appendSampleBuffer(sampleBuffer)
    }

    private func addReplaceVideoInner(cameraId: UUID, name: String) {
        replaceVideos[cameraId] = ReplaceVideo(name: name, update: true)
    }

    private func removeReplaceVideoInner(cameraId: UUID) {
        replaceVideos.removeValue(forKey: cameraId)
    }

    private func makeBlackSampleBuffer(
        duration: CMTime,
        presentationTimeStamp: CMTime,
        decodeTimeStamp: CMTime
    ) -> CMSampleBuffer? {
        if blackImageBuffer == nil || blackFormatDescription == nil {
            let width = outputSize.width
            let height = outputSize.height
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
                return nil
            }
            CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, blackPixelBufferPool, &blackImageBuffer)
            guard let blackImageBuffer else {
                return nil
            }
            let image = createBlackImage(width: Double(width), height: Double(height))
            CIContext().render(image, to: blackImageBuffer)
            blackFormatDescription = CMVideoFormatDescription.create(imageBuffer: blackImageBuffer)
            guard blackFormatDescription != nil else {
                return nil
            }
        }
        return CMSampleBuffer.create(blackImageBuffer!,
                                     blackFormatDescription!,
                                     duration,
                                     presentationTimeStamp,
                                     decodeTimeStamp)
    }

    private func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer,
                                    isFirstAfterAttach: Bool,
                                    applyBlur: Bool) -> Bool
    {
        guard let imageBuffer = sampleBuffer.imageBuffer else {
            return false
        }
        if sampleBuffer.presentationTimeStamp < latestSampleBufferAppendTime {
            logger.info(
                """
                Discarding video frame: \(sampleBuffer.presentationTimeStamp.seconds) \
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
        guard let imageBuffer = sampleBuffer.imageBuffer else {
            return
        }
        var newImageBuffer: CVImageBuffer?
        var newSampleBuffer: CMSampleBuffer?
        if isFirstAfterAttach {
            usePendingAfterAttachEffectsInner()
        }
        if !effects.isEmpty || applyBlur || imageBuffer.size != outputSize {
            (newImageBuffer, newSampleBuffer) = applyEffects(
                imageBuffer,
                sampleBuffer,
                faceDetections,
                applyBlur,
                isFirstAfterAttach
            )
            removeEffects()
        }
        let modImageBuffer = newImageBuffer ?? imageBuffer
        let modSampleBuffer = newSampleBuffer ?? sampleBuffer
        modSampleBuffer.setAttachmentDisplayImmediately()
        drawable?.enqueue(modSampleBuffer, isFirstAfterAttach: isFirstAfterAttach)
        encoder.encodeImageBuffer(
            modImageBuffer,
            presentationTimeStamp: modSampleBuffer.presentationTimeStamp,
            duration: modSampleBuffer.duration
        )
        mixer?.recorder.appendVideo(
            modImageBuffer,
            withPresentationTime: modSampleBuffer.presentationTimeStamp
        )
        if lowFpsImageEnabled {
            let presentationTimeStamp = modSampleBuffer.presentationTimeStamp.seconds
            if lowFpsImageLatest + lowFpsImageInterval < presentationTimeStamp {
                lowFpsImageLatest = presentationTimeStamp
                lowFpsImageQueue.async {
                    self.createLowFpsImage(imageBuffer: modImageBuffer)
                }
            }
        }
        if let takeSnapshotComplete {
            DispatchQueue.global().async {
                self.takeSnapshot(imageBuffer: modImageBuffer, onComplete: takeSnapshotComplete)
            }
            self.takeSnapshotComplete = nil
        }
    }

    private func createLowFpsImage(imageBuffer: CVImageBuffer) {
        var ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let scale = 400.0 / Double(imageBuffer.width)
        ciImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let cgImage = context.createCGImage(ciImage, from: ciImage.extent)!
        let image = UIImage(cgImage: cgImage)
        mixer?.delegate?.mixerVideo(
            lowFpsImage: image.jpegData(compressionQuality: 0.3),
            frameNumber: lowFpsImageFrameNumber
        )
        lowFpsImageFrameNumber += 1
    }

    private func takeSnapshot(imageBuffer: CVImageBuffer, onComplete: @escaping (UIImage) -> Void) {
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let cgImage = context.createCGImage(ciImage, from: ciImage.extent)!
        let image = UIImage(cgImage: cgImage)
        onComplete(image)
    }

    private func anyEffectNeedsFaceDetections() -> Bool {
        for effect in effects where effect.needsFaceDetections() {
            return true
        }
        return false
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
            width: Int32(captureSize.width),
            height: Int32(captureSize.height),
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

    private func attachDevice(_ device: AVCaptureDevice?, _ session: AVCaptureSession) throws {
        if let connection, session.connections.contains(connection) {
            session.removeConnection(connection)
        }
        if let input, session.inputs.contains(input) {
            session.removeInput(input)
        }
        if let output, session.outputs.contains(output) {
            session.removeOutput(output)
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
            if session.canAddInput(input!) {
                session.addInputWithNoConnections(input!)
            }
            if session.canAddOutput(output!) {
                session.addOutputWithNoConnections(output!)
            }
            if let connection, session.canAddConnection(connection) {
                session.addConnection(connection)
            }
            session.automaticallyConfiguresCaptureDeviceForWideColor = false
        } else {
            input = nil
            output = nil
            connection = nil
        }
    }

    private func setTorchMode(_ device: AVCaptureDevice, _ torchMode: AVCaptureDevice.TorchMode) {
        guard device.isTorchModeSupported(torchMode) else {
            if torchMode == .on {
                mixer?.delegate?.mixerNoTorch()
            }
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

    private func appendNewSampleBuffer(sampleBuffer: CMSampleBuffer) {
        let now = ContinuousClock.now
        if firstFrameTime == nil {
            firstFrameTime = now
        }
        guard firstFrameTime!.duration(to: now) > .seconds(ioVideoUnitIgnoreFramesAfterAttachSeconds) else {
            return
        }
        latestSampleBuffer = sampleBuffer
        latestSampleBufferTime = now
        if appendSampleBuffer(sampleBuffer, isFirstAfterAttach: isFirstAfterAttach, applyBlur: false) {
            isFirstAfterAttach = false
        }
    }
}

extension VideoUnit: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from _: AVCaptureConnection
    ) {
        replaceVideos[builtinCameraId]?.setLatestSampleBuffer(sampleBuffer: sampleBuffer)
        guard selectedReplaceVideoCameraId == nil else {
            return
        }
        appendNewSampleBuffer(sampleBuffer: sampleBuffer)
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
