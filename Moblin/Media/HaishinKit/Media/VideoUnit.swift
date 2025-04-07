import AVFoundation
import Collections
import CoreImage
import MetalPetal
import UIKit
import Vision

enum SceneSwitchTransition {
    case blur
    case freeze
    case blurAndZoom
}

struct CaptureDevice {
    let device: AVCaptureDevice?
    let id: UUID
}

var pixelFormatType = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
var ioVideoUnitMetalPetal = false
var allowVideoRangePixelFormat = false
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
    let isSceneSwitchTransition: Bool
    var faceDetections: [VNFaceObservation]?
}

private class ReplaceVideo {
    private var sampleBuffers: Deque<CMSampleBuffer> = []
    private var currentSampleBuffer: CMSampleBuffer?
    private var isInitialBuffering = true
    private var cameraId: UUID
    private let name: String
    private let update: Bool
    private weak var mixer: Mixer?
    private let driftTracker: DriftTracker
    private var hasBufferBeenAppended = false

    init(cameraId: UUID, name: String, update: Bool, latency: Double, mixer: Mixer?) {
        self.cameraId = cameraId
        self.name = name
        self.update = update
        self.mixer = mixer
        driftTracker = DriftTracker(media: "video", name: name, targetFillLevel: latency)
    }

    func setTargetLatency(latency: Double) {
        driftTracker.setTargetFillLevel(targetFillLevel: latency)
    }

    func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        hasBufferBeenAppended = true
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
        var sampleBuffer: CMSampleBuffer?
        var numberOfBuffersConsumed = 0
        let drift = driftTracker.getDrift()
        while let inputSampleBuffer = sampleBuffers.first {
            if currentSampleBuffer == nil {
                currentSampleBuffer = inputSampleBuffer
            }
            if sampleBuffers.count > 200 {
                logger.info("""
                replace-video: \(name): Over 200 frames (\(sampleBuffers.count)) buffered. Dropping \
                oldest frame.
                """)
                sampleBuffer = inputSampleBuffer
                sampleBuffers.removeFirst()
                numberOfBuffersConsumed += 1
                continue
            }
            let inputPresentationTimeStamp = inputSampleBuffer.presentationTimeStamp.seconds + drift
            let inputOutputDelta = inputPresentationTimeStamp - outputPresentationTimeStamp
            // Break on first frame that is ahead in time.
            if inputOutputDelta > 0, sampleBuffer != nil || abs(inputOutputDelta) > 0.01 {
                break
            }
            sampleBuffer = inputSampleBuffer
            sampleBuffers.removeFirst()
            numberOfBuffersConsumed += 1
            isInitialBuffering = false
        }
        if logger.debugEnabled, !isInitialBuffering {
            let lastPresentationTimeStamp = sampleBuffers.last?.presentationTimeStamp.seconds ?? 0.0
            let firstPresentationTimeStamp = sampleBuffers.first?.presentationTimeStamp.seconds ?? 0.0
            let fillLevel = lastPresentationTimeStamp - firstPresentationTimeStamp
            if numberOfBuffersConsumed == 0 {
                logger.debug("""
                replace-video: \(name): Duplicating buffer. \
                Output \(formatThreeDecimals(outputPresentationTimeStamp)), \
                Current \(formatThreeDecimals(currentSampleBuffer?.presentationTimeStamp.seconds ?? 0.0)), \
                \(formatThreeDecimals(firstPresentationTimeStamp + drift))..\
                \(formatThreeDecimals(lastPresentationTimeStamp + drift)) \
                (\(formatThreeDecimals(fillLevel))), \
                Buffers \(sampleBuffers.count)
                """)
            } else if numberOfBuffersConsumed > 1 {
                logger.debug("""
                replace-video: \(name): Dropping \(numberOfBuffersConsumed - 1) buffer(s). \
                Output \(formatThreeDecimals(outputPresentationTimeStamp)), \
                Current \(formatThreeDecimals(currentSampleBuffer?.presentationTimeStamp.seconds ?? 0.0)), \
                \(formatThreeDecimals(firstPresentationTimeStamp + drift))..\
                \(formatThreeDecimals(lastPresentationTimeStamp + drift)) \
                (\(formatThreeDecimals(fillLevel))), \
                Buffers \(sampleBuffers.count)
                """)
            }
        }
        if sampleBuffer != nil {
            currentSampleBuffer = sampleBuffer
        }
        if !isInitialBuffering, hasBufferBeenAppended {
            hasBufferBeenAppended = false
            if let drift = driftTracker.update(outputPresentationTimeStamp, sampleBuffers) {
                mixer?.setReplaceAudioDrift(cameraId: cameraId, drift: drift)
            }
        }
    }

    func setLatestSampleBuffer(sampleBuffer: CMSampleBuffer?) {
        currentSampleBuffer = sampleBuffer
    }

    func getSampleBuffer(_ presentationTimeStamp: CMTime) -> CMSampleBuffer? {
        return currentSampleBuffer?.replacePresentationTimeStamp(presentationTimeStamp)
    }

    func setDrift(drift: Double) {
        driftTracker.setDrift(drift: drift)
    }
}

struct CaptureSessionDevice {
    var device: AVCaptureDevice
    var input: AVCaptureInput
    var output: AVCaptureVideoDataOutput
    var connection: AVCaptureConnection
}

final class VideoUnit: NSObject {
    static let defaultFrameRate: Float64 = 30
    private(set) var device: AVCaptureDevice?
    private var captureSessionDevices: [CaptureSessionDevice] = []
    private let context = CIContext()
    private let metalPetalContext: MTIContext?
    weak var drawable: PreviewView?
    weak var externalDisplayDrawable: PreviewView?
    private var nextFaceDetectionsSequenceNumber: UInt64 = 0
    private var nextCompletedFaceDetectionsSequenceNumber: UInt64 = 0
    private var completedFaceDetections: [UInt64: FaceDetectionsCompletion] = [:]
    private var captureSize = CGSize(width: 1920, height: 1080)
    private var outputSize = CGSize(width: 1920, height: 1080)
    private var fillFrame = true
    let session = makeVideoCaptureSession()
    private var encoders = [VideoEncoder(lockQueue: mixerLockQueue)]
    weak var mixer: Mixer?
    private var effects: [VideoEffect] = []
    private var pendingAfterAttachEffects: [VideoEffect]?
    private var pendingAfterAttachRotation: Double?
    private var videoUnitBuiltinDevice: VideoUnitBuiltinDevice!

    var frameRate = VideoUnit.defaultFrameRate {
        didSet {
            session.beginConfiguration()
            for device in captureSessionDevices {
                setDeviceFormat(
                    device: device.device,
                    frameRate: frameRate,
                    preferAutoFrameRate: preferAutoFrameRate,
                    colorSpace: colorSpace
                )
            }
            session.commitConfiguration()
            startFrameTimer()
        }
    }

    var preferAutoFrameRate = false {
        didSet {
            session.beginConfiguration()
            for device in captureSessionDevices {
                setDeviceFormat(
                    device: device.device,
                    frameRate: frameRate,
                    preferAutoFrameRate: preferAutoFrameRate,
                    colorSpace: colorSpace
                )
            }
            session.commitConfiguration()
        }
    }

    var colorSpace: AVCaptureColorSpace = .sRGB {
        didSet {
            session.beginConfiguration()
            for device in captureSessionDevices {
                setDeviceFormat(
                    device: device.device,
                    frameRate: frameRate,
                    preferAutoFrameRate: preferAutoFrameRate,
                    colorSpace: colorSpace
                )
            }
            session.commitConfiguration()
        }
    }

    var videoOrientation: AVCaptureVideoOrientation = .portrait {
        didSet {
            guard videoOrientation != oldValue else {
                return
            }
            session.beginConfiguration()
            for device in captureSessionDevices {
                for connection in device.output.connections.filter({ $0.isVideoOrientationSupported }) {
                    setOrientation(device: device.device, connection: connection, orientation: videoOrientation)
                }
            }
            session.commitConfiguration()
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
    fileprivate var replaceVideos: [UUID: ReplaceVideo] = [:]
    fileprivate var replaceVideoBuiltins: [AVCaptureDevice?: ReplaceVideo] = [:]
    private var blackImageBuffer: CVPixelBuffer?
    private var blackFormatDescription: CMVideoFormatDescription?
    private var blackPixelBufferPool: CVPixelBufferPool?
    private var latestSampleBuffer: CMSampleBuffer?
    private var latestSampleBufferTime: ContinuousClock.Instant?
    private var frameTimer = SimpleTimer(queue: mixerLockQueue)
    private var firstFrameTime: ContinuousClock.Instant?
    private var isFirstAfterAttach = false
    private var ignoreFramesAfterAttachSeconds = 0.0
    private var configuredIgnoreFramesAfterAttachSeconds = 0.0
    private var rotation: Double = 0.0
    private var latestSampleBufferAppendTime: CMTime = .zero
    private var lowFpsImageEnabled: Bool = false
    private var lowFpsImageInterval: Double = 1.0
    private var lowFpsImageLatest: Double = 0.0
    private var lowFpsImageFrameNumber: UInt64 = 0
    private var takeSnapshotAge: Float = 0.0
    private var takeSnapshotComplete: ((UIImage, CIImage) -> Void)?
    private var takeSnapshotSampleBuffers: Deque<CMSampleBuffer> = []
    private var cleanRecordings = false
    private var cleanSnapshots = false
    private var cleanExternalDisplay = false
    private var pool: CVPixelBufferPool?
    private var poolColorSpace: CGColorSpace?
    private var poolFormatDescriptionExtension: CFDictionary?
    private var cameraControlsEnabled = false
    private var isRunning = false
    private var showCameraPreview = false
    private var externalDisplayPreview = false
    private var sceneSwitchTransition: SceneSwitchTransition = .blur

    override init() {
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            metalPetalContext = try? MTIContext(device: metalDevice)
        } else {
            metalPetalContext = nil
        }
        videoUnitBuiltinDevice = nil
        super.init()
        videoUnitBuiltinDevice = VideoUnitBuiltinDevice(videoUnit: self)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleSessionRuntimeError),
                                               name: .AVCaptureSessionRuntimeError,
                                               object: session)
        startFrameTimer()
    }

    deinit {
        stopFrameTimer()
    }

    @objc
    private func handleSessionRuntimeError(_ notification: NSNotification) {
        guard let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError else {
            return
        }
        let message = error._nsError.localizedFailureReason ?? "\(error.code)"
        mixer?.delegate?.mixerCaptureSessionError(message: message)
        netStreamLockQueue.asyncAfter(deadline: .now() + .milliseconds(500)) {
            if self.isRunning {
                self.session.startRunning()
            }
        }
    }

    func startRunning() {
        isRunning = true
        addSessionObservers()
        session.startRunning()
    }

    func stopRunning() {
        isRunning = false
        removeSessionObservers()
        session.stopRunning()
    }

    func setCameraControl(enabled: Bool) {
        cameraControlsEnabled = enabled
        session.beginConfiguration()
        updateCameraControls()
        session.commitConfiguration()
    }

    func getEncoders() -> [VideoEncoder] {
        return encoders
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

    func attach(
        _ devices: [CaptureDevice],
        _ cameraPreviewLayer: AVCaptureVideoPreviewLayer?,
        _ showCameraPreview: Bool,
        _ externalDisplayPreview: Bool,
        _ replaceVideo: UUID?,
        _ preferredVideoStabilizationMode: AVCaptureVideoStabilizationMode,
        _ isVideoMirrored: Bool,
        _ ignoreFramesAfterAttachSeconds: Double,
        _ fillFrame: Bool
    ) throws {
        for device in captureSessionDevices {
            device.output.setSampleBufferDelegate(nil, queue: mixerLockQueue)
        }
        logger.info("Number of video devices: \(devices.count)")
        mixerLockQueue.async {
            self.configuredIgnoreFramesAfterAttachSeconds = ignoreFramesAfterAttachSeconds
            self.selectedReplaceVideoCameraId = replaceVideo
            self.prepareFirstFrame()
            self.showCameraPreview = showCameraPreview
            self.externalDisplayPreview = externalDisplayPreview
            self.fillFrame = fillFrame
            self.replaceVideoBuiltins.removeAll()
            for device in devices {
                let replaceVideo = ReplaceVideo(
                    cameraId: device.id,
                    name: "",
                    update: false,
                    latency: 0.0,
                    mixer: self.mixer
                )
                self.replaceVideos[device.id] = replaceVideo
                self.replaceVideoBuiltins[device.device] = replaceVideo
            }
        }
        for device in devices {
            setDeviceFormat(
                device: device.device,
                frameRate: frameRate,
                preferAutoFrameRate: preferAutoFrameRate,
                colorSpace: colorSpace
            )
        }
        session.beginConfiguration()
        defer {
            session.commitConfiguration()
        }
        try removeDevices(session)
        for device in devices {
            try attachDevice(device.device, session)
        }
        session.automaticallyConfiguresCaptureDeviceForWideColor = false
        device = devices.first?.device
        for device in captureSessionDevices {
            for connection in device.output.connections {
                if connection.isVideoMirroringSupported {
                    connection.isVideoMirrored = isVideoMirrored
                }
                if connection.isVideoOrientationSupported {
                    setOrientation(device: device.device, connection: connection, orientation: videoOrientation)
                }
                if connection.isVideoStabilizationSupported {
                    connection.preferredVideoStabilizationMode = preferredVideoStabilizationMode
                }
            }
        }
        for (i, device) in captureSessionDevices.enumerated() {
            if i == 0 {
                device.output.setSampleBufferDelegate(self, queue: mixerLockQueue)
            } else {
                device.output.setSampleBufferDelegate(videoUnitBuiltinDevice, queue: mixerLockQueue)
            }
        }
        updateCameraControls()
        cameraPreviewLayer?.session = nil
        if showCameraPreview {
            cameraPreviewLayer?.session = session
        }
    }

    private func getReplaceVideoForDevice(device: CaptureDevice?) -> ReplaceVideo? {
        switch device?.device?.position {
        case .back:
            return replaceVideos[builtinBackCameraId]!
        case .front:
            return replaceVideos[builtinFrontCameraId]!
        case .unspecified:
            return replaceVideos[externalCameraId]!
        default:
            return nil
        }
    }

    func registerEffect(_ effect: VideoEffect) {
        mixerLockQueue.sync {
            self.registerEffectInner(effect)
        }
    }

    func unregisterEffect(_ effect: VideoEffect) {
        mixerLockQueue.sync {
            self.unregisterEffectInner(effect)
        }
    }

    func setPendingAfterAttachEffects(effects: [VideoEffect], rotation: Double) {
        mixerLockQueue.sync {
            self.setPendingAfterAttachEffectsInner(effects: effects, rotation: rotation)
        }
    }

    func usePendingAfterAttachEffects() {
        mixerLockQueue.sync {
            self.usePendingAfterAttachEffectsInner()
        }
    }

    func setLowFpsImage(fps: Float) {
        mixerLockQueue.async {
            self.setLowFpsImageInner(fps: fps)
        }
    }

    func setSceneSwitchTransition(sceneSwitchTransition: SceneSwitchTransition) {
        mixerLockQueue.async {
            self.sceneSwitchTransition = sceneSwitchTransition
        }
    }

    func takeSnapshot(age: Float, onComplete: @escaping (UIImage, CIImage) -> Void) {
        mixerLockQueue.async {
            self.takeSnapshotAge = age
            self.takeSnapshotComplete = onComplete
        }
    }

    func setCleanRecordings(enabled: Bool) {
        mixerLockQueue.async {
            self.cleanRecordings = enabled
        }
    }

    func setCleanSnapshots(enabled: Bool) {
        mixerLockQueue.async {
            self.cleanSnapshots = enabled
        }
    }

    func setCleanExternalDisplay(enabled: Bool) {
        mixerLockQueue.async {
            self.cleanExternalDisplay = enabled
        }
    }

    func addReplaceVideoSampleBuffer(cameraId: UUID, _ sampleBuffer: CMSampleBuffer) {
        mixerLockQueue.async {
            self.addReplaceVideoSampleBufferInner(cameraId: cameraId, sampleBuffer)
        }
    }

    func addReplaceVideo(cameraId: UUID, name: String, latency: Double) {
        mixerLockQueue.async {
            self.addReplaceVideoInner(cameraId: cameraId, name: name, latency: latency)
        }
    }

    func removeReplaceVideo(cameraId: UUID) {
        mixerLockQueue.async {
            self.removeReplaceVideoInner(cameraId: cameraId)
        }
    }

    func setReplaceVideoDrift(cameraId: UUID, drift: Double) {
        mixerLockQueue.async {
            self.setReplaceVideoDriftInner(cameraId: cameraId, drift: drift)
        }
    }

    private func setReplaceVideoDriftInner(cameraId: UUID, drift: Double) {
        replaceVideos[cameraId]?.setDrift(drift: drift)
    }

    func setReplaceVideoTargetLatency(cameraId: UUID, latency: Double) {
        mixerLockQueue.async {
            self.setReplaceVideoTargetLatencyInner(cameraId: cameraId, latency: latency)
        }
    }

    private func setReplaceVideoTargetLatencyInner(cameraId: UUID, latency: Double) {
        replaceVideos[cameraId]?.setTargetLatency(latency: latency)
    }

    func startEncoding(_ delegate: any VideoEncoderDelegate) {
        for encoder in encoders {
            encoder.delegate = delegate
            encoder.startRunning()
        }
    }

    func stopEncoding() {
        for encoder in encoders {
            encoder.stopRunning()
            encoder.delegate = nil
        }
    }

    func setCaptureSize(size: CGSize) {
        captureSize = size
    }

    func setOutputSize(size: CGSize) {
        outputSize = size
    }

    private func startFrameTimer() {
        let frameInterval = 1 / frameRate
        frameTimer.startPeriodic(interval: frameInterval) { [weak self] in
            self?.handleFrameTimer()
        }
    }

    private func stopFrameTimer() {
        frameTimer.stop()
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
            isSceneSwitchTransition: true
        )
    }

    private func prepareFirstFrame() {
        firstFrameTime = nil
        isFirstAfterAttach = true
        ignoreFramesAfterAttachSeconds = configuredIgnoreFramesAfterAttachSeconds
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
                              _ isSceneSwitchTransition: Bool,
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
                isSceneSwitchTransition,
                info
            )
        } else if ioVideoUnitMetalPetal {
            return applyEffectsMetalPetal(
                imageBuffer,
                sampleBuffer,
                isSceneSwitchTransition,
                info
            )
        } else {
            return applyEffectsCoreImage(
                imageBuffer,
                sampleBuffer,
                isSceneSwitchTransition,
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
        if (fillFrame && (outputRatio < imageRatio)) || (!fillFrame && (outputRatio > imageRatio)) {
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
            .cropped(to: CGRect(x: 0, y: 0, width: outputSize.width, height: outputSize.height))
            .composited(over: getBlackImage(
                width: Double(outputSize.width),
                height: Double(outputSize.height)
            ))
    }

    private func rotateCoreImage(_ image: CIImage, _ rotation: Double) -> CIImage {
        switch rotation {
        case 90:
            return image.oriented(.right)
        case 180:
            return image.oriented(.down)
        case 270:
            return image.oriented(.left)
        default:
            return image
        }
    }

    private func applyEffectsCoreImage(_ imageBuffer: CVImageBuffer,
                                       _ sampleBuffer: CMSampleBuffer,
                                       _ isSceneSwitchTransition: Bool,
                                       _ info: VideoEffectInfo) -> (CVImageBuffer?, CMSampleBuffer?)
    {
        var image = CIImage(cvPixelBuffer: imageBuffer)
        if videoOrientation != .portrait && imageBuffer.isPortrait() {
            image = image.oriented(.left)
        }
        image = rotateCoreImage(image, rotation)
        if image.extent.size != outputSize {
            image = scaleImage(image)
        }
        let extent = image.extent
        var failedEffect: String?
        if isSceneSwitchTransition {
            image = applySceneSwitchTransition(image)
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

    private func applySceneSwitchTransitionMetalPetal(_ image: MTIImage?) -> MTIImage? {
        guard let image else {
            return nil
        }
        let filter = MTIMPSGaussianBlurFilter()
        filter.inputImage = image
        filter.radius = calcBlurRadius() * Float(image.extent.size.maximum() / 1920)
        return filter.outputImage
    }

    private func applyEffectsMetalPetal(_ imageBuffer: CVImageBuffer,
                                        _ sampleBuffer: CMSampleBuffer,
                                        _ isSceneSwitchTransition: Bool,
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
        if isSceneSwitchTransition {
            image = applySceneSwitchTransitionMetalPetal(image)
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
                .transformed(by: CGAffineTransform(translationX: -smallOffsetX, y: -smallOffsetY))
                .transformed(by: CGAffineTransform(scaleX: scaleUpFactor, y: scaleUpFactor))
                .cropped(to: image.extent) ?? image
        }
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

    private func setPendingAfterAttachEffectsInner(effects: [VideoEffect], rotation: Double) {
        pendingAfterAttachEffects = effects
        pendingAfterAttachRotation = rotation
    }

    private func usePendingAfterAttachEffectsInner() {
        if let pendingAfterAttachEffects {
            for effect in effects where !pendingAfterAttachEffects.contains(effect) {
                effect.removed()
            }
            effects = pendingAfterAttachEffects
            self.pendingAfterAttachEffects = nil
        }
        if let pendingAfterAttachRotation {
            rotation = pendingAfterAttachRotation
            self.pendingAfterAttachRotation = nil
        }
    }

    private func setLowFpsImageInner(fps: Float) {
        lowFpsImageInterval = Double(1 / fps).clamped(to: 0.2 ... 1.0)
        lowFpsImageEnabled = fps != 0.0
        lowFpsImageLatest = 0.0
    }

    private func addReplaceVideoSampleBufferInner(cameraId: UUID, _ sampleBuffer: CMSampleBuffer) {
        guard let replaceVideo = replaceVideos[cameraId] else {
            return
        }
        replaceVideo.appendSampleBuffer(sampleBuffer)
    }

    private func addReplaceVideoInner(cameraId: UUID, name: String, latency: Double) {
        replaceVideos[cameraId] = ReplaceVideo(
            cameraId: cameraId,
            name: name,
            update: true,
            latency: latency,
            mixer: mixer
        )
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
                                    isSceneSwitchTransition: Bool) -> Bool
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
            isSceneSwitchTransition: isSceneSwitchTransition
        )
        nextFaceDetectionsSequenceNumber += 1
        if anyEffectNeedsFaceDetections() {
            detectionsQueue.async {
                let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: imageBuffer)
                let faceLandmarksRequest = VNDetectFaceLandmarksRequest { request, error in
                    mixerLockQueue.async {
                        guard error == nil else {
                            self.faceDetectionsComplete(completion)
                            return
                        }
                        // Only use 5 biggest to limit processing.
                        if let results = (request as? VNDetectFaceLandmarksRequest)?
                            .results?
                            .sorted(by: { a, b in a.boundingBox.height > b.boundingBox.height })
                            .prefix(5)
                        {
                            completion.faceDetections = Array(results)
                        }
                        self.faceDetectionsComplete(completion)
                    }
                }
                do {
                    try imageRequestHandler.perform([faceLandmarksRequest])
                } catch {
                    mixerLockQueue.async {
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
                completion.isSceneSwitchTransition,
                completion.faceDetections
            )
            nextCompletedFaceDetectionsSequenceNumber += 1
        }
    }

    private func appendSampleBufferWithFaceDetections(
        _ sampleBuffer: CMSampleBuffer,
        _ isFirstAfterAttach: Bool,
        _ isSceneSwitchTransition: Bool,
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
        if !effects.isEmpty || isSceneSwitchTransition || imageBuffer.size != outputSize || rotation != 0.0 {
            (newImageBuffer, newSampleBuffer) = applyEffects(
                imageBuffer,
                sampleBuffer,
                faceDetections,
                isSceneSwitchTransition,
                isFirstAfterAttach
            )
            removeEffects()
        }
        let modImageBuffer = newImageBuffer ?? imageBuffer
        let modSampleBuffer = newSampleBuffer ?? sampleBuffer
        // Recordings seems to randomly fail if moved after live stream encoding. Maybe because the
        // sample buffer is copied in appendVideo()
        if cleanRecordings {
            mixer?.recorder.appendVideo(sampleBuffer)
        } else {
            mixer?.recorder.appendVideo(modSampleBuffer)
        }
        modSampleBuffer.setAttachmentDisplayImmediately()
        if !showCameraPreview {
            drawable?.enqueue(modSampleBuffer, isFirstAfterAttach: isFirstAfterAttach)
        }
        if externalDisplayPreview {
            if cleanExternalDisplay {
                externalDisplayDrawable?.enqueue(sampleBuffer, isFirstAfterAttach: isFirstAfterAttach)
            } else {
                externalDisplayDrawable?.enqueue(modSampleBuffer, isFirstAfterAttach: isFirstAfterAttach)
            }
        }
        for encoder in encoders {
            encoder.encodeImageBuffer(
                modImageBuffer,
                presentationTimeStamp: modSampleBuffer.presentationTimeStamp,
                duration: modSampleBuffer.duration
            )
        }
        let presentationTimeStamp = sampleBuffer.presentationTimeStamp.seconds
        handleLowFpsImage(modImageBuffer, presentationTimeStamp)
        if cleanSnapshots {
            handleTakeSnapshot(sampleBuffer, presentationTimeStamp)
        } else {
            handleTakeSnapshot(modSampleBuffer, presentationTimeStamp)
        }
    }

    private func handleLowFpsImage(_ imageBuffer: CVImageBuffer, _ presentationTimeStamp: Double) {
        guard lowFpsImageEnabled else {
            return
        }
        guard presentationTimeStamp > lowFpsImageLatest + lowFpsImageInterval else {
            return
        }
        lowFpsImageLatest = presentationTimeStamp
        lowFpsImageQueue.async {
            self.createLowFpsImage(imageBuffer: imageBuffer)
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

    private func handleTakeSnapshot(_ sampleBuffer: CMSampleBuffer, _ presentationTimeStamp: Double) {
        let latestPresentationTimeStamp = takeSnapshotSampleBuffers.last?.presentationTimeStamp.seconds ?? 0.0
        if presentationTimeStamp > latestPresentationTimeStamp + 3.0 {
            takeSnapshotSampleBuffers.append(sampleBuffer)
            // Can only save a few sample buffers from captureOutput(). Can save more if effects
            // are applied (sample buffer is copied).
            if takeSnapshotSampleBuffers.count > 3 {
                takeSnapshotSampleBuffers.removeFirst()
            }
        }
        guard let takeSnapshotComplete else {
            return
        }
        DispatchQueue.global().async {
            self.takeSnapshot(
                sampleBuffer,
                self.takeSnapshotSampleBuffers,
                presentationTimeStamp,
                self.takeSnapshotAge,
                takeSnapshotComplete
            )
        }
        self.takeSnapshotComplete = nil
    }

    private func findBestSnapshot(_ sampleBuffer: CMSampleBuffer,
                                  _ sampleBuffers: Deque<CMSampleBuffer>,
                                  _ presentationTimeStamp: Double,
                                  _ age: Float,
                                  _ onCompleted: @escaping (CVImageBuffer?) -> Void)
    {
        if age == 0.0 {
            onCompleted(sampleBuffer.imageBuffer)
        } else {
            let requestedPresentationTimeStamp = presentationTimeStamp - Double(age)
            let sampleBufferAtAge = sampleBuffers.last(where: {
                $0.presentationTimeStamp.seconds <= requestedPresentationTimeStamp
            }) ?? sampleBuffers.first ?? sampleBuffer
            if #available(iOS 18, *) {
                var sampleBuffers = sampleBuffers
                sampleBuffers.append(sampleBuffer)
                findBestSnapshotUsingAesthetics(sampleBufferAtAge, sampleBuffers, onCompleted)
            } else {
                onCompleted(sampleBufferAtAge.imageBuffer)
            }
        }
    }

    @available(iOS 18, *)
    private func findBestSnapshotUsingAesthetics(_ preferredSampleBuffer: CMSampleBuffer,
                                                 _ sampleBuffers: Deque<CMSampleBuffer>,
                                                 _ onComplete: @escaping (CVImageBuffer?) -> Void)
    {
        Task {
            var bestSampleBuffer = preferredSampleBuffer
            var bestResult = try? await CalculateImageAestheticsScoresRequest().perform(on: preferredSampleBuffer)
            for sampleBuffer in sampleBuffers {
                guard let result = try? await CalculateImageAestheticsScoresRequest().perform(on: sampleBuffer) else {
                    continue
                }
                if bestResult == nil || result.overallScore > bestResult!.overallScore + 0.2 {
                    bestSampleBuffer = sampleBuffer
                    bestResult = result
                }
            }
            onComplete(bestSampleBuffer.imageBuffer)
        }
    }

    private func takeSnapshot(_ sampleBuffer: CMSampleBuffer,
                              _ sampleBuffers: Deque<CMSampleBuffer>,
                              _ presentationTimeStamp: Double,
                              _ age: Float,
                              _ onComplete: @escaping (UIImage, CIImage) -> Void)
    {
        findBestSnapshot(sampleBuffer, sampleBuffers, presentationTimeStamp, age) { imageBuffer in
            guard let imageBuffer else {
                return
            }
            let ciImage = CIImage(cvPixelBuffer: imageBuffer)
            let cgImage = self.context.createCGImage(ciImage, from: ciImage.extent)!
            let image = UIImage(cgImage: cgImage)
            var portraitImage = ciImage
            if !imageBuffer.isPortrait() {
                portraitImage = portraitImage.oriented(.left)
            }
            onComplete(image, portraitImage)
        }
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
        logger.debug("Video session interruption started")
        mixerLockQueue.async {
            self.prepareFirstFrame()
        }
    }

    @objc
    private func sessionInterruptionEnded(_: Notification) {
        logger.debug("Video session interruption ended")
    }

    private func findVideoFormat(
        device: AVCaptureDevice,
        width: Int32,
        height: Int32,
        frameRate: Float64,
        preferAutoFrameRate: Bool,
        colorSpace: AVCaptureColorSpace
    ) -> (AVCaptureDevice.Format?, Bool, String?) {
        var useAutoFrameRate = false
        var formats = device.formats
        formats = formats.filter { $0.isFrameRateSupported(frameRate) }
        if #available(iOS 18, *), preferAutoFrameRate {
            let autoFrameRateFormats = formats.filter { $0.isAutoVideoFrameRateSupported }
            if !autoFrameRateFormats.isEmpty {
                formats = autoFrameRateFormats
                useAutoFrameRate = true
            }
        }
        formats = formats.filter { $0.formatDescription.dimensions.width == width }
        formats = formats.filter { $0.formatDescription.dimensions.height == height }
        formats = formats.filter { $0.supportedColorSpaces.contains(colorSpace) }
        if formats.isEmpty {
            return (nil, useAutoFrameRate, "No video format found matching \(height)p\(Int(frameRate)), \(colorSpace)")
        }
        formats = formats.filter { !$0.isVideoBinned }
        if formats.isEmpty {
            return (nil, useAutoFrameRate, "No unbinned video format found")
        }
        // 420v does not work with OA4.
        formats = formats.filter {
            $0.formatDescription.mediaSubType.rawValue != kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
                || allowVideoRangePixelFormat
        }
        if formats.isEmpty {
            return (nil, useAutoFrameRate, "Unsupported video pixel format")
        }
        return (formats.first, useAutoFrameRate, nil)
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

    private func setDeviceFormat(
        device: AVCaptureDevice?,
        frameRate: Float64,
        preferAutoFrameRate: Bool,
        colorSpace: AVCaptureColorSpace
    ) {
        guard let device else {
            return
        }
        let (format, useAutoFrameRate, error) = findVideoFormat(
            device: device,
            width: Int32(captureSize.width),
            height: Int32(captureSize.height),
            frameRate: frameRate,
            preferAutoFrameRate: preferAutoFrameRate,
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
            if useAutoFrameRate {
                device.setAutoFps()
                mixer?.delegate?.mixerSelectedFps(fps: frameRate, auto: true)
            } else {
                device.setFps(frameRate: frameRate)
                mixer?.delegate?.mixerSelectedFps(fps: frameRate, auto: false)
            }
            device.unlockForConfiguration()
        } catch {
            logger.error("while locking device for fps: \(error)")
        }
    }

    private func attachDevice(_ device: AVCaptureDevice?, _ session: AVCaptureSession) throws {
        guard let device else {
            return
        }
        let input = try AVCaptureDeviceInput(device: device)
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: pixelFormatType,
        ]
        var connection: AVCaptureConnection?
        if let port = input.ports.first(where: { $0.mediaType == .video }) {
            connection = AVCaptureConnection(inputPorts: [port], output: output)
        }
        var failed = false
        if session.canAddInput(input) {
            session.addInputWithNoConnections(input)
        } else {
            failed = true
        }
        if session.canAddOutput(output) {
            session.addOutputWithNoConnections(output)
        } else {
            failed = true
        }
        if let connection, session.canAddConnection(connection) {
            session.addConnection(connection)
        } else {
            failed = true
        }
        if failed {
            mixer?.delegate?.mixerAttachCameraError()
        } else {
            captureSessionDevices.append(CaptureSessionDevice(
                device: device,
                input: input,
                output: output,
                connection: connection!
            ))
        }
    }

    private func removeDevices(_ session: AVCaptureSession) throws {
        for device in captureSessionDevices {
            try removeConnection(session, device.connection)
            try removeInput(session, device.input)
            try removeOutput(session, device.output)
        }
        captureSessionDevices.removeAll()
    }

    private func removeConnection(_ session: AVCaptureSession, _ connection: AVCaptureConnection?) throws {
        if let connection, session.connections.contains(connection) {
            session.removeConnection(connection)
        }
    }

    private func removeInput(_ session: AVCaptureSession, _ input: AVCaptureInput?) throws {
        if let input, session.inputs.contains(input) {
            session.removeInput(input)
        }
    }

    private func removeOutput(_ session: AVCaptureSession, _ output: AVCaptureOutput?) throws {
        if let output, session.outputs.contains(output) {
            session.removeOutput(output)
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
        guard firstFrameTime!.duration(to: now) > .seconds(ignoreFramesAfterAttachSeconds) else {
            return
        }
        latestSampleBuffer = sampleBuffer
        latestSampleBufferTime = now
        if appendSampleBuffer(sampleBuffer, isFirstAfterAttach: isFirstAfterAttach, isSceneSwitchTransition: false) {
            isFirstAfterAttach = false
        }
    }

    private func updateCameraControls() {
        guard #available(iOS 18, *) else {
            return
        }
        if session.supportsControls {
            removeCameraControls()
            addCameraControls()
        }
    }

    @available(iOS 18.0, *)
    func addCameraControls() {
        guard cameraControlsEnabled, let device else {
            return
        }
        let zoomSlider = AVCaptureSystemZoomSlider(device: device) { [weak self] zoomFactor in
            let x = Float(device.displayVideoZoomFactorMultiplier * zoomFactor)
            self?.mixer?.delegate?.mixerSetZoomX(x: x)
        }
        if session.canAddControl(zoomSlider) {
            session.addControl(zoomSlider)
        }
        let exposureBiasSlider = AVCaptureSystemExposureBiasSlider(device: device) { [weak self] exposureBias in
            self?.mixer?.delegate?.mixerSetExposureBias(bias: exposureBias)
        }
        if session.canAddControl(exposureBiasSlider) {
            session.addControl(exposureBiasSlider)
        }
        session.setControlsDelegate(self, queue: netStreamLockQueue)
    }

    @available(iOS 18.0, *)
    func removeCameraControls() {
        for control in session.controls {
            session.removeControl(control)
        }
        session.setControlsDelegate(nil, queue: nil)
    }
}

extension VideoUnit: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let input = connection.inputPorts.first?.input as? AVCaptureDeviceInput else {
            return
        }
        replaceVideoBuiltins[input.device]?.setLatestSampleBuffer(sampleBuffer: sampleBuffer)
        guard selectedReplaceVideoCameraId == nil else {
            return
        }
        appendNewSampleBuffer(sampleBuffer: sampleBuffer)
    }
}

class VideoUnitBuiltinDevice: NSObject {
    weak var videoUnit: VideoUnit?

    init(videoUnit: VideoUnit) {
        self.videoUnit = videoUnit
    }
}

extension VideoUnitBuiltinDevice: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let input = connection.inputPorts.first?.input as? AVCaptureDeviceInput else {
            return
        }
        videoUnit?.replaceVideoBuiltins[input.device]?.setLatestSampleBuffer(sampleBuffer: sampleBuffer)
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

@available(iOS 18.0, *)
extension VideoUnit: AVCaptureSessionControlsDelegate {
    func sessionControlsDidBecomeActive(_: AVCaptureSession) {}

    func sessionControlsWillEnterFullscreenAppearance(_: AVCaptureSession) {}

    func sessionControlsWillExitFullscreenAppearance(_: AVCaptureSession) {}

    func sessionControlsDidBecomeInactive(_: AVCaptureSession) {}
}
