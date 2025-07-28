import AVFoundation
import Collections
import CoreImage
import MetalPetal
import UIKit
import VideoToolbox
import Vision

struct FaceDetectionJob {
    let videoSourceId: UUID
    let imageBuffer: CVPixelBuffer
}

struct VideoUnitAttachParams {
    let devices: CaptureDevices
    let builtinDelay: Double
    let cameraPreviewLayer: AVCaptureVideoPreviewLayer
    let showCameraPreview: Bool
    let externalDisplayPreview: Bool
    let bufferedVideo: UUID?
    let preferredVideoStabilizationMode: AVCaptureVideoStabilizationMode
    let isVideoMirrored: Bool
    let ignoreFramesAfterAttachSeconds: Double
    let fillFrame: Bool
}

enum SceneSwitchTransition {
    case blur
    case freeze
    case blurAndZoom
}

struct CaptureDevice {
    let device: AVCaptureDevice?
    let id: UUID
}

struct CaptureDevices {
    var hasSceneDevice: Bool
    var devices: [CaptureDevice]
}

var pixelFormatType = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
var ioVideoUnitMetalPetal = false
var allowVideoRangePixelFormat = false
private let detectionsQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.Detections", attributes: .concurrent)
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

private class FaceDetectionsCompletion {
    // periphery:ignore
    let sequenceNumber: UInt64
    let sampleBuffer: CMSampleBuffer
    let isFirstAfterAttach: Bool
    let isSceneSwitchTransition: Bool
    let faceDetectionJobs: [FaceDetectionJob]
    var faceDetections: [UUID: [VNFaceObservation]]

    init(
        sequenceNumber: UInt64,
        sampleBuffer: CMSampleBuffer,
        isFirstAfterAttach: Bool,
        isSceneSwitchTransition: Bool,
        faceDetectionJobs: [FaceDetectionJob]
    ) {
        self.sequenceNumber = sequenceNumber
        self.sampleBuffer = sampleBuffer
        self.isFirstAfterAttach = isFirstAfterAttach
        self.isSceneSwitchTransition = isSceneSwitchTransition
        self.faceDetectionJobs = faceDetectionJobs
        faceDetections = [:]
    }
}

private struct CaptureSessionDevice {
    let device: AVCaptureDevice
    let input: AVCaptureInput
    let output: AVCaptureVideoDataOutput
    let connection: AVCaptureConnection
}

private func makeCaptureSession() -> AVCaptureSession {
    let session = AVCaptureMultiCamSession()
    if session.isMultitaskingCameraAccessSupported {
        session.isMultitaskingCameraAccessEnabled = true
    }
    return session
}

final class VideoUnit: NSObject {
    static let defaultFrameRate: Float64 = 30
    private var device: AVCaptureDevice?
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
    let session = makeCaptureSession()
    let encoder = VideoEncoder(lockQueue: processorPipelineQueue)
    weak var processor: Processor?
    private var effects: [VideoEffect] = []
    private var pendingAfterAttachEffects: [VideoEffect]?
    private var pendingAfterAttachRotation: Double?
    private var videoUnitBuiltinDevice: VideoUnitBuiltinDevice?
    private var sceneVideoSourceId = UUID()
    private var selectedBufferedVideoCameraId: UUID?
    fileprivate var bufferedVideos: [UUID: BufferedVideo] = [:]
    fileprivate var bufferedVideoBuiltins: [AVCaptureDevice?: BufferedVideo] = [:]
    private var blackImageBuffer: CVPixelBuffer?
    private var blackFormatDescription: CMVideoFormatDescription?
    private var blackPixelBufferPool: CVPixelBufferPool?
    private var latestSampleBuffer: CMSampleBuffer?
    private var latestSampleBufferTime: ContinuousClock.Instant?
    private var sceneSwitchEndRendered = false
    private var frameTimer = SimpleTimer(queue: processorPipelineQueue)
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
    private var takeSnapshotComplete: ((UIImage, CIImage, CIImage) -> Void)?
    private var takeSnapshotSampleBuffers: Deque<CMSampleBuffer> = []
    private var cleanRecordings = false
    private var cleanSnapshots = false
    private var cleanExternalDisplay = false
    private var pool: CVPixelBufferPool?
    private var poolColorSpace: CGColorSpace?
    private var poolFormatDescriptionExtension: CFDictionary?
    private var bufferedPool: CVPixelBufferPool?
    private var bufferedPoolColorSpace: CGColorSpace?
    private var bufferedPoolFormatDescriptionExtension: CFDictionary?
    private var cameraControlsEnabled = false
    private var isRunning = false
    private var showCameraPreview = false
    private var screenPreviewEnabled = true
    private var externalDisplayPreview = false
    private var sceneSwitchTransition: SceneSwitchTransition = .blur
    private var pixelTransferSession: VTPixelTransferSession?
    private var previousFaceDetectionTimes: [UUID: Double] = [:]
    private var fps = VideoUnit.defaultFrameRate
    private var preferAutoFps = false
    private var colorSpace: AVCaptureColorSpace = .sRGB
    private var blackImage: CIImage?

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
                    processor?.delegate?.streamNoTorch()
                }
                return
            }
            setTorchMode(device, torch ? .on : .off)
        }
    }

    override init() {
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            metalPetalContext = try? MTIContext(device: metalDevice)
        } else {
            metalPetalContext = nil
        }
        videoUnitBuiltinDevice = nil
        VTPixelTransferSessionCreate(allocator: nil, pixelTransferSessionOut: &pixelTransferSession)
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

    func setFps(fps: Float64, preferAutoFps: Bool) {
        self.fps = fps
        self.preferAutoFps = preferAutoFps
        updateDevicesFormat()
        startFrameTimer()
    }

    func getFps() -> Double {
        return fps
    }

    func setColorSpace(colorSpace: AVCaptureColorSpace) {
        self.colorSpace = colorSpace
        updateDevicesFormat()
    }

    func setCameraControl(enabled: Bool) {
        cameraControlsEnabled = enabled
        session.beginConfiguration()
        updateCameraControls()
        session.commitConfiguration()
    }

    func registerEffect(_ effect: VideoEffect) {
        processorPipelineQueue.async {
            self.registerEffectInner(effect)
        }
    }

    func registerEffectBack(_ effect: VideoEffect) {
        processorPipelineQueue.async {
            self.registerEffectBackInner(effect)
        }
    }

    func unregisterEffect(_ effect: VideoEffect) {
        processorPipelineQueue.async {
            self.unregisterEffectInner(effect)
        }
    }

    func setPendingAfterAttachEffects(effects: [VideoEffect], rotation: Double) {
        processorControlQueue.async {
            processorPipelineQueue.async {
                self.setPendingAfterAttachEffectsInner(effects: effects, rotation: rotation)
            }
        }
    }

    func usePendingAfterAttachEffects() {
        processorControlQueue.async {
            processorPipelineQueue.async {
                self.usePendingAfterAttachEffectsInner()
            }
        }
    }

    func setScreenPreview(enabled: Bool) {
        processorControlQueue.async {
            processorPipelineQueue.async {
                self.screenPreviewEnabled = enabled
            }
        }
    }

    func setLowFpsImage(fps: Float) {
        processorPipelineQueue.async {
            self.setLowFpsImageInner(fps: fps)
        }
    }

    func setSceneSwitchTransition(sceneSwitchTransition: SceneSwitchTransition) {
        processorPipelineQueue.async {
            self.sceneSwitchTransition = sceneSwitchTransition
        }
    }

    func takeSnapshot(age: Float, onComplete: @escaping (UIImage, CIImage, CIImage) -> Void) {
        processorPipelineQueue.async {
            self.takeSnapshotAge = age
            self.takeSnapshotComplete = onComplete
        }
    }

    func setCleanRecordings(enabled: Bool) {
        processorPipelineQueue.async {
            self.cleanRecordings = enabled
        }
    }

    func setCleanSnapshots(enabled: Bool) {
        processorPipelineQueue.async {
            self.cleanSnapshots = enabled
        }
    }

    func setCleanExternalDisplay(enabled: Bool) {
        processorPipelineQueue.async {
            self.cleanExternalDisplay = enabled
        }
    }

    func appendBufferedVideoSampleBuffer(cameraId: UUID, _ sampleBuffer: CMSampleBuffer) {
        processorPipelineQueue.async {
            self.appendBufferedVideoSampleBufferInner(cameraId: cameraId, sampleBuffer)
        }
    }

    func addBufferedVideo(cameraId: UUID, name: String, latency: Double) {
        processorPipelineQueue.async {
            self.addBufferedVideoInner(cameraId: cameraId, name: name, latency: latency)
        }
    }

    func removeBufferedVideo(cameraId: UUID) {
        processorPipelineQueue.async {
            self.removeBufferedVideoInner(cameraId: cameraId)
        }
    }

    func setBufferedVideoDrift(cameraId: UUID, drift: Double) {
        processorPipelineQueue.async {
            self.setBufferedVideoDriftInner(cameraId: cameraId, drift: drift)
        }
    }

    func setBufferedVideoTargetLatency(cameraId: UUID, latency: Double) {
        processorPipelineQueue.async {
            self.setBufferedVideoTargetLatencyInner(cameraId: cameraId, latency: latency)
        }
    }

    func startEncoding(_ delegate: any VideoEncoderDelegate) {
        encoder.delegate = delegate
        encoder.startRunning()
    }

    func stopEncoding() {
        encoder.stopRunning()
        encoder.delegate = nil
    }

    func setSize(capture: CGSize, output: CGSize) {
        captureSize = capture
        outputSize = output
        updateDevicesFormat()
        processorPipelineQueue.async {
            self.blackImage = nil
            self.pool = nil
            self.bufferedPool = nil
        }
    }

    func getCiImage(_ videoSourceId: UUID, _ presentationTimeStamp: CMTime) -> CIImage? {
        guard let sampleBuffer = bufferedVideos[videoSourceId]?.getSampleBuffer(presentationTimeStamp),
              let imageBuffer = sampleBuffer.imageBuffer
        else {
            return nil
        }
        return CIImage(cvPixelBuffer: imageBuffer)
    }

    func attach(params: VideoUnitAttachParams) throws {
        for device in captureSessionDevices {
            device.output.setSampleBufferDelegate(nil, queue: processorPipelineQueue)
        }
        processorPipelineQueue.async {
            self.configuredIgnoreFramesAfterAttachSeconds = params.ignoreFramesAfterAttachSeconds
            self.selectedBufferedVideoCameraId = params.bufferedVideo
            self.prepareFirstFrame()
            self.showCameraPreview = params.showCameraPreview
            self.externalDisplayPreview = params.externalDisplayPreview
            self.fillFrame = params.fillFrame
            if let bufferedVideo = params.bufferedVideo {
                self.sceneVideoSourceId = bufferedVideo
            } else if params.devices.hasSceneDevice, let id = params.devices.devices.first?.id {
                self.sceneVideoSourceId = id
            } else {
                self.sceneVideoSourceId = UUID()
            }
            self.bufferedVideoBuiltins.removeAll()
            for device in params.devices.devices {
                let bufferedVideo = BufferedVideo(
                    cameraId: device.id,
                    name: device.device?.localizedName ?? "builtin",
                    update: false,
                    latency: params.builtinDelay,
                    processor: self.processor
                )
                self.bufferedVideos[device.id] = bufferedVideo
                self.bufferedVideoBuiltins[device.device] = bufferedVideo
            }
            if self.pendingAfterAttachEffects == nil {
                self.pendingAfterAttachEffects = self.effects
            }
            for effect in self.effects where effect is VideoSourceEffect {
                self.unregisterEffectInner(effect)
            }
        }
        for device in params.devices.devices {
            setDeviceFormat(
                device: device.device,
                fps: fps,
                preferAutoFrameRate: preferAutoFps,
                colorSpace: colorSpace
            )
        }
        session.beginConfiguration()
        defer {
            session.commitConfiguration()
        }
        try removeDevices(session)
        for device in params.devices.devices {
            try attachDevice(device.device, session)
        }
        session.automaticallyConfiguresCaptureDeviceForWideColor = false
        device = params.devices.hasSceneDevice ? params.devices.devices.first?.device : nil
        for device in captureSessionDevices {
            for connection in device.output.connections {
                if connection.isVideoMirroringSupported {
                    connection.isVideoMirrored = params.isVideoMirrored
                }
                if connection.isVideoOrientationSupported {
                    setOrientation(device: device.device, connection: connection, orientation: videoOrientation)
                }
                if connection.isVideoStabilizationSupported {
                    connection.preferredVideoStabilizationMode = params.preferredVideoStabilizationMode
                }
            }
        }
        for (i, device) in captureSessionDevices.enumerated() {
            if params.devices.hasSceneDevice, i == 0 {
                device.output.setSampleBufferDelegate(self, queue: processorPipelineQueue)
            } else {
                device.output.setSampleBufferDelegate(videoUnitBuiltinDevice, queue: processorPipelineQueue)
            }
        }
        updateCameraControls()
        params.cameraPreviewLayer.session = nil
        if params.showCameraPreview {
            params.cameraPreviewLayer.session = session
        }
    }

    @objc
    private func handleSessionRuntimeError(_ notification: NSNotification) {
        guard let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError else {
            return
        }
        let message = error._nsError.localizedFailureReason ?? "\(error.code)"
        processor?.delegate?.streamVideoCaptureSessionError(message)
        processorControlQueue.asyncAfter(deadline: .now() + .milliseconds(500)) {
            if self.isRunning {
                self.session.startRunning()
            }
        }
    }

    private func updateDevicesFormat() {
        for device in captureSessionDevices {
            setDeviceFormat(
                device: device.device,
                fps: fps,
                preferAutoFrameRate: preferAutoFps,
                colorSpace: colorSpace
            )
        }
    }

    private func getBufferedVideoForDevice(device: CaptureDevice?) -> BufferedVideo? {
        switch device?.device?.position {
        case .back:
            return bufferedVideos[builtinBackCameraId]!
        case .front:
            return bufferedVideos[builtinFrontCameraId]!
        case .unspecified:
            return bufferedVideos[externalCameraId]!
        default:
            return nil
        }
    }

    private func setBufferedVideoDriftInner(cameraId: UUID, drift: Double) {
        bufferedVideos[cameraId]?.setDrift(drift: drift)
    }

    private func setBufferedVideoTargetLatencyInner(cameraId: UUID, latency: Double) {
        bufferedVideos[cameraId]?.setTargetLatency(latency: latency)
    }

    private func startFrameTimer() {
        let frameInterval = 1 / fps
        frameTimer.startPeriodic(interval: frameInterval) { [weak self] in
            self?.handleFrameTimer()
        }
    }

    private func stopFrameTimer() {
        frameTimer.stop()
    }

    private func handleFrameTimer() {
        let presentationTimeStamp = currentPresentationTimeStamp()
        handleBufferedVideo(presentationTimeStamp)
        handleGapFillerTimer()
    }

    private func handleBufferedVideo(_ presentationTimeStamp: CMTime) {
        for bufferedVideo in bufferedVideos.values {
            bufferedVideo.updateSampleBuffer(presentationTimeStamp.seconds)
        }
        guard let selectedBufferedVideoCameraId else {
            return
        }
        for bufferedVideoBuiltin in bufferedVideoBuiltins.values where bufferedVideoBuiltin.latency > 0 {
            bufferedVideoBuiltin.updateSampleBuffer(presentationTimeStamp.seconds, true)
        }
        if let sampleBuffer = bufferedVideos[selectedBufferedVideoCameraId]?.getSampleBuffer(presentationTimeStamp) {
            appendNewSampleBuffer(sampleBuffer: sampleBuffer)
        } else if let sampleBuffer = makeBlackSampleBuffer(
            duration: .invalid,
            presentationTimeStamp: presentationTimeStamp,
            decodeTimeStamp: .invalid
        ) {
            appendNewSampleBuffer(sampleBuffer: sampleBuffer)
        } else {
            logger.info("buffered-video: Failed to output frame")
        }
    }

    private func handleGapFillerTimer() {
        guard isFirstAfterAttach else {
            return
        }
        guard var latestSampleBuffer, let latestSampleBufferTime else {
            return
        }
        let delta = latestSampleBufferTime.duration(to: .now)
        guard delta > .seconds(0.05) else {
            return
        }
        let isSceneSwitchTransition = !isAtEndOfSceneSwitchTransition()
        if !isSceneSwitchTransition, !sceneSwitchEndRendered {
            latestSampleBuffer = renderSceneSwitchTransitionEnd(sampleBuffer: latestSampleBuffer)
            self.latestSampleBuffer = latestSampleBuffer
            sceneSwitchEndRendered = true
        }
        let timeDelta = CMTime(seconds: delta.seconds)
        let newPresentationTimeStamp = latestSampleBuffer.presentationTimeStamp + timeDelta
        guard let sampleBuffer = latestSampleBuffer.replacePresentationTimeStamp(newPresentationTimeStamp) else {
            return
        }
        _ = appendSampleBuffer(
            sampleBuffer,
            isFirstAfterAttach: false,
            isSceneSwitchTransition: isSceneSwitchTransition
        )
    }

    private func isAtEndOfSceneSwitchTransition() -> Bool {
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

    private func renderSceneSwitchTransitionEnd(sampleBuffer: CMSampleBuffer) -> CMSampleBuffer {
        guard let imageBuffer = sampleBuffer.imageBuffer else {
            return sampleBuffer
        }
        var image = CIImage(cvPixelBuffer: imageBuffer)
        image = applySceneSwitchTransition(image)
        guard let outputImageBuffer = createPixelBuffer(sampleBuffer: sampleBuffer) else {
            return sampleBuffer
        }
        if let poolColorSpace {
            context.render(image, to: outputImageBuffer, bounds: image.extent, colorSpace: poolColorSpace)
        } else {
            context.render(image, to: outputImageBuffer)
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

    private func getBufferedBufferPool(sampleBuffer: CMSampleBuffer) -> CVPixelBufferPool? {
        guard let formatDescription = sampleBuffer.formatDescription else {
            return nil
        }
        let formatDescriptionExtension = formatDescription.extensions()
        if let bufferedPool, formatDescriptionExtension == bufferedPoolFormatDescriptionExtension {
            return bufferedPool
        }
        var attributes: [NSString: AnyObject] = [:]
        if let imageBuffer = sampleBuffer.imageBuffer {
            NSDictionary(dictionary: CVPixelBufferCopyCreationAttributes(imageBuffer))
                .enumerateKeysAndObjects { key, value, _ in
                    attributes[key as! CFString] = value as AnyObject
                }
        }
        attributes[kCVPixelBufferPixelFormatTypeKey] = NSNumber(value: pixelFormatType)
        attributes[kCVPixelBufferIOSurfacePropertiesKey] = NSDictionary()
        attributes[kCVPixelBufferMetalCompatibilityKey] = kCFBooleanTrue
        attributes[kCVPixelBufferWidthKey] = NSNumber(value: outputSize.width)
        attributes[kCVPixelBufferHeightKey] = NSNumber(value: outputSize.height)
        bufferedPoolColorSpace = nil
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
                attributes[kCVBufferPropagatedAttachmentsKey] = colorSpaceProperties as AnyObject
            }
            if let colorSpace = formatDescriptionExtension[kCVImageBufferCGColorSpaceKey] {
                bufferedPoolColorSpace = (colorSpace as! CGColorSpace)
            } else if let colorPrimaries = colorPrimaries as? String {
                if colorPrimaries == (kCVImageBufferColorPrimaries_P3_D65 as String) {
                    bufferedPoolColorSpace = CGColorSpace(name: CGColorSpace.displayP3)
                } else if #available(iOS 17.2, *),
                          formatDescriptionExtension[kCVImageBufferLogTransferFunctionKey] as? String ==
                          kCVImageBufferLogTransferFunction_AppleLog as String
                {
                    bufferedPoolColorSpace = CGColorSpace(name: CGColorSpace.itur_2020)
                    // bufferedPoolColorSpace = CGColorSpace(name: CGColorSpace.extendedITUR_2020)
                    // bufferedPoolColorSpace = CGColorSpace(name: CGColorSpace.displayP3)
                    // bufferedPoolColorSpace = nil
                }
            }
        }
        bufferedPoolFormatDescriptionExtension = formatDescriptionExtension
        bufferedPool = nil
        CVPixelBufferPoolCreate(
            nil,
            nil,
            attributes as NSDictionary?,
            &bufferedPool
        )
        return bufferedPool
    }

    private func createBufferedPixelBuffer(sampleBuffer: CMSampleBuffer) -> CVPixelBuffer? {
        guard let pool = getBufferedBufferPool(sampleBuffer: sampleBuffer) else {
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
                              _ faceDetectionJobs: [FaceDetectionJob],
                              _ faceDetections: [UUID: [VNFaceObservation]],
                              _ isSceneSwitchTransition: Bool,
                              _ isFirstAfterAttach: Bool) -> (CVImageBuffer?, CMSampleBuffer?)
    {
        let info = VideoEffectInfo(
            isFirstAfterAttach: isFirstAfterAttach,
            sceneVideoSourceId: sceneVideoSourceId,
            faceDetectionJobs: faceDetectionJobs,
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
        if videoOrientation != .portrait, imageBuffer.isPortrait() {
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
        processor?.delegate?.streamVideo(failedEffect: failedEffect)
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
        processor?.delegate?.streamVideo(failedEffect: failedEffect)
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

    private func registerEffectBackInner(_ effect: VideoEffect) {
        if !effects.contains(effect) {
            effects.insert(effect, at: 0)
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

    private func appendBufferedVideoSampleBufferInner(cameraId: UUID, _ sampleBuffer: CMSampleBuffer) {
        guard let bufferedVideo = bufferedVideos[cameraId] else {
            return
        }
        bufferedVideo.appendSampleBuffer(sampleBuffer)
    }

    private func addBufferedVideoInner(cameraId: UUID, name: String, latency: Double) {
        bufferedVideos[cameraId] = BufferedVideo(
            cameraId: cameraId,
            name: name,
            update: true,
            latency: latency,
            processor: processor
        )
    }

    private func removeBufferedVideoInner(cameraId: UUID) {
        bufferedVideos.removeValue(forKey: cameraId)
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
        let presentationTimeStamp = sampleBuffer.presentationTimeStamp.seconds
        processor?.delegate?.streamVideo(presentationTimestamp: presentationTimeStamp)
        let faceDetectionVideoSourceIds = needsFaceDetections(presentationTimeStamp)
        let faceDetectionJobs = prepareFaceDetectionJobs(
            faceDetectionVideoSourceIds,
            sampleBuffer.presentationTimeStamp,
            imageBuffer
        )
        let completion = FaceDetectionsCompletion(
            sequenceNumber: nextFaceDetectionsSequenceNumber,
            sampleBuffer: sampleBuffer,
            isFirstAfterAttach: isFirstAfterAttach,
            isSceneSwitchTransition: isSceneSwitchTransition,
            faceDetectionJobs: faceDetectionJobs
        )
        nextFaceDetectionsSequenceNumber += 1
        if !faceDetectionJobs.isEmpty {
            for faceDetectionJob in faceDetectionJobs {
                detectionsQueue.async {
                    let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: faceDetectionJob.imageBuffer)
                    let faceLandmarksRequest = VNDetectFaceLandmarksRequest { request, error in
                        processorPipelineQueue.async {
                            guard error == nil else {
                                completion.faceDetections[faceDetectionJob.videoSourceId] = []
                                self.faceDetectionsComplete(completion)
                                return
                            }
                            // Only use 5 biggest to limit processing.
                            if let results = (request as? VNDetectFaceLandmarksRequest)?
                                .results?
                                .sorted(by: { a, b in a.boundingBox.height > b.boundingBox.height })
                                .prefix(5)
                            {
                                completion.faceDetections[faceDetectionJob.videoSourceId] = Array(results)
                            } else {
                                completion.faceDetections[faceDetectionJob.videoSourceId] = []
                            }
                            self.faceDetectionsComplete(completion)
                        }
                    }
                    do {
                        try imageRequestHandler.perform([faceLandmarksRequest])
                    } catch {
                        processorPipelineQueue.async {
                            completion.faceDetections[faceDetectionJob.videoSourceId] = []
                            self.faceDetectionsComplete(completion)
                        }
                    }
                }
            }
        } else {
            faceDetectionsComplete(completion)
        }
        return true
    }

    private func faceDetectionsComplete(_ completion: FaceDetectionsCompletion) {
        guard completion.faceDetections.count == completion.faceDetectionJobs.count else {
            return
        }
        completedFaceDetections[completion.sequenceNumber] = completion
        while let completion = completedFaceDetections
            .removeValue(forKey: nextCompletedFaceDetectionsSequenceNumber)
        {
            appendSampleBufferWithFaceDetections(
                completion.sampleBuffer,
                completion.isFirstAfterAttach,
                completion.isSceneSwitchTransition,
                completion.faceDetectionJobs,
                completion.faceDetections
            )
            nextCompletedFaceDetectionsSequenceNumber += 1
        }
    }

    private func appendSampleBufferWithFaceDetections(
        _ sampleBuffer: CMSampleBuffer,
        _ isFirstAfterAttach: Bool,
        _ isSceneSwitchTransition: Bool,
        _ faceDetectionJobs: [FaceDetectionJob],
        _ faceDetections: [UUID: [VNFaceObservation]]
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
                faceDetectionJobs,
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
            processor?.recorder.appendVideo(sampleBuffer)
        } else {
            processor?.recorder.appendVideo(modSampleBuffer)
        }
        modSampleBuffer.setAttachmentDisplayImmediately()
        if !showCameraPreview, screenPreviewEnabled {
            drawable?.enqueue(modSampleBuffer, isFirstAfterAttach: isFirstAfterAttach)
        }
        if externalDisplayPreview {
            if cleanExternalDisplay {
                externalDisplayDrawable?.enqueue(sampleBuffer, isFirstAfterAttach: isFirstAfterAttach)
            } else {
                externalDisplayDrawable?.enqueue(modSampleBuffer, isFirstAfterAttach: isFirstAfterAttach)
            }
        }
        encoder.encodeImageBuffer(
            modImageBuffer,
            presentationTimeStamp: modSampleBuffer.presentationTimeStamp,
            duration: modSampleBuffer.duration
        )
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
        processor?.delegate?.streamVideo(
            lowFpsImage: image.jpegData(compressionQuality: 0.3),
            frameNumber: lowFpsImageFrameNumber
        )
        lowFpsImageFrameNumber += 1
    }

    private func handleTakeSnapshot(_ sampleBuffer: CMSampleBuffer, _ presentationTimeStamp: Double) {
        let latestPresentationTimeStamp = takeSnapshotSampleBuffers.last?.presentationTimeStamp.seconds ?? 0.0
        if presentationTimeStamp > latestPresentationTimeStamp + 3.0 {
            guard let sampleBuffer = makeCopy(sampleBuffer: sampleBuffer) else {
                return
            }
            takeSnapshotSampleBuffers.append(sampleBuffer)
            if takeSnapshotSampleBuffers.count > 3 {
                takeSnapshotSampleBuffers.removeFirst()
            }
        }
        guard let takeSnapshotComplete else {
            return
        }
        guard let sampleBuffer = makeCopy(sampleBuffer: sampleBuffer) else {
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
                              _ onComplete: @escaping (UIImage, CIImage, CIImage) -> Void)
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
            onComplete(image, ciImage, portraitImage)
        }
    }

    private func needsFaceDetections(_ presentationTimeStamp: Double) -> Set<UUID> {
        var faceDetectionsIntervals: [UUID: Double] = [:]
        var ids: Set<UUID> = []
        for effect in effects {
            let (needsFaceDetectionsNow, videoSource, interval) = effect.needsFaceDetections(presentationTimeStamp)
            let videoSourceId = videoSource ?? sceneVideoSourceId
            if let interval {
                if let currentInterval = faceDetectionsIntervals[videoSourceId] {
                    if interval < currentInterval {
                        faceDetectionsIntervals[videoSourceId] = interval
                    }
                } else {
                    faceDetectionsIntervals[videoSourceId] = interval
                }
            }
            if needsFaceDetectionsNow {
                ids.insert(videoSourceId)
                previousFaceDetectionTimes[videoSourceId] = presentationTimeStamp
            }
        }
        for (videoSourceId, interval) in faceDetectionsIntervals {
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

    private func prepareFaceDetectionJobs(
        _ faceDetectionVideoSourceIds: Set<UUID>,
        _ presentationTimeStamp: CMTime,
        _ imageBuffer: CVImageBuffer
    ) -> [FaceDetectionJob] {
        var faceDetectionVideoSources: [FaceDetectionJob] = []
        for videoSourceId in faceDetectionVideoSourceIds {
            var videoSourceImageBuffer: CVPixelBuffer?
            if videoSourceId == sceneVideoSourceId {
                videoSourceImageBuffer = imageBuffer
            } else {
                videoSourceImageBuffer = bufferedVideos[videoSourceId]?.getSampleBuffer(presentationTimeStamp)?
                    .imageBuffer
            }
            guard let videoSourceImageBuffer else {
                faceDetectionVideoSources.removeAll()
                break
            }
            faceDetectionVideoSources.append(FaceDetectionJob(videoSourceId: videoSourceId,
                                                              imageBuffer: videoSourceImageBuffer))
        }
        return faceDetectionVideoSources
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
        processorPipelineQueue.async {
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
        fps: Float64,
        preferAutoFrameRate: Bool,
        colorSpace: AVCaptureColorSpace
    ) -> (AVCaptureDevice.Format?, Bool, String?) {
        var useAutoFrameRate = false
        var formats = device.formats
        formats = formats.filter { $0.isFrameRateSupported(fps) }
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
            return (nil, useAutoFrameRate, "No video format found matching \(height)p\(Int(fps)), \(colorSpace)")
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
        processor?.delegate?.streamVideo(findVideoFormatError: error, activeFormat: activeFormat)
        for format in device.formats {
            logger.info("Available video format: \(format)")
        }
    }

    private func setDeviceFormat(
        device: AVCaptureDevice?,
        fps: Float64,
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
            fps: fps,
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
                processor?.delegate?.streamSelectedFps(fps: fps, auto: true)
            } else {
                device.setFps(frameRate: fps)
                processor?.delegate?.streamSelectedFps(fps: fps, auto: false)
            }
            device.unlockForConfiguration()
        } catch {
            logger.error("Error while locking device: \(error)")
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
            processor?.delegate?.streamVideoAttachCameraError()
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
                processor?.delegate?.streamNoTorch()
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
        sceneSwitchEndRendered = false
        if appendSampleBuffer(sampleBuffer, isFirstAfterAttach: isFirstAfterAttach, isSceneSwitchTransition: false) {
            isFirstAfterAttach = false
        }
    }

    private func makeCopy(sampleBuffer: CMSampleBuffer) -> CMSampleBuffer? {
        guard let imageBufferCopy = createBufferedPixelBuffer(sampleBuffer: sampleBuffer) else {
            return nil
        }
        VTPixelTransferSessionTransferImage(
            pixelTransferSession!,
            from: sampleBuffer.imageBuffer!,
            to: imageBufferCopy
        )
        return CMSampleBuffer.create(
            imageBufferCopy,
            sampleBuffer.formatDescription!,
            sampleBuffer.duration,
            sampleBuffer.presentationTimeStamp,
            sampleBuffer.decodeTimeStamp
        )
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
            self?.processor?.delegate?.streamSetZoomX(x: x)
        }
        if session.canAddControl(zoomSlider) {
            session.addControl(zoomSlider)
        }
        let exposureBiasSlider = AVCaptureSystemExposureBiasSlider(device: device) { [weak self] exposureBias in
            self?.processor?.delegate?.streamSetExposureBias(bias: exposureBias)
        }
        if session.canAddControl(exposureBiasSlider) {
            session.addControl(exposureBiasSlider)
        }
        session.setControlsDelegate(self, queue: processorControlQueue)
    }

    @available(iOS 18.0, *)
    func removeCameraControls() {
        for control in session.controls {
            session.removeControl(control)
        }
        session.setControlsDelegate(nil, queue: nil)
    }

    fileprivate func appendBufferedBuiltinVideo(_ sampleBuffer: CMSampleBuffer,
                                                _ device: AVCaptureDevice) -> BufferedVideo?
    {
        guard let bufferedVideo = bufferedVideoBuiltins[device] else {
            return nil
        }
        guard bufferedVideo.latency > 0 else {
            bufferedVideo.setLatestSampleBuffer(sampleBuffer)
            return nil
        }
        var sampleBufferCopy: CMSampleBuffer
        if bufferedVideo.latency > 0.07 || bufferedVideo.numberOfBuffers() > 4 {
            sampleBufferCopy = makeCopy(sampleBuffer: sampleBuffer) ?? sampleBuffer
        } else {
            sampleBufferCopy = sampleBuffer
        }
        let presentationTimeStamp = sampleBufferCopy.presentationTimeStamp + CMTime(seconds: bufferedVideo.latency)
        sampleBufferCopy = sampleBufferCopy.replacePresentationTimeStamp(presentationTimeStamp) ?? sampleBufferCopy
        bufferedVideo.appendSampleBuffer(sampleBufferCopy)
        return bufferedVideo
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
        var sampleBuffer = sampleBuffer
        if let bufferedVideo = appendBufferedBuiltinVideo(sampleBuffer, input.device) {
            for bufferedVideoBuiltin in bufferedVideoBuiltins.values {
                bufferedVideoBuiltin.updateSampleBuffer(sampleBuffer.presentationTimeStamp.seconds, true)
            }
            sampleBuffer = bufferedVideo.getSampleBuffer(sampleBuffer.presentationTimeStamp) ?? sampleBuffer
        }
        guard selectedBufferedVideoCameraId == nil else {
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
        _ = videoUnit?.appendBufferedBuiltinVideo(sampleBuffer, input.device)
    }
}

private func createBlackImage(width: Double, height: Double) -> CIImage {
    return CIImage.black.cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
}

@available(iOS 18.0, *)
extension VideoUnit: AVCaptureSessionControlsDelegate {
    func sessionControlsDidBecomeActive(_: AVCaptureSession) {}

    func sessionControlsWillEnterFullscreenAppearance(_: AVCaptureSession) {}

    func sessionControlsWillExitFullscreenAppearance(_: AVCaptureSession) {}

    func sessionControlsDidBecomeInactive(_: AVCaptureSession) {}
}
