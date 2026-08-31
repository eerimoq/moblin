import AVFoundation
import CoreImage
import MetalPetal
import Photos
import SwiftUI
import VideoToolbox
@preconcurrency import Vision

private let deltaLimit = 0.03

struct DetectionJob {
    let videoSourceId: UUID
    let imageBuffer: CVPixelBuffer
    let detectFaces: Bool
    let detectText: Bool
}

struct VideoUnitAttachParams: @unchecked Sendable {
    let devices: CaptureDevices
    let builtinDelay: Double
    let cameraPreviewLayer: AVCaptureVideoPreviewLayer
    let showCameraPreview: Bool
    let externalDisplayPreview: Bool
    let bufferedVideo: UUID?
    let preferredVideoStabilizationMode: AVCaptureVideoStabilizationMode
    let ignoreFramesAfterAttachSeconds: Double
    let fillFrame: Bool
    let isLandscapeStreamAndPortraitUi: Bool
    let forceSceneTransition: Bool
    let macScreenCapture: Bool
    let photoShoot: Bool

    func canQuickSwitchTo(other: VideoUnitAttachParams) -> Bool {
        if devices.devices.count != other.devices.devices.count {
            return false
        }
        for device in devices.devices {
            if let otherDevice = other.devices.devices.first(where: { $0.id == device.id }) {
                if device.isVideoMirrored != otherDevice.isVideoMirrored {
                    return false
                }
            } else {
                return false
            }
        }
        if showCameraPreview {
            return false
        }
        if builtinDelay != other.builtinDelay {
            return false
        }
        if preferredVideoStabilizationMode != other.preferredVideoStabilizationMode {
            return false
        }
        if isLandscapeStreamAndPortraitUi != other.isLandscapeStreamAndPortraitUi {
            return false
        }
        if forceSceneTransition {
            return false
        }
        if macScreenCapture != other.macScreenCapture {
            return false
        }
        if photoShoot != other.photoShoot {
            return false
        }
        return true
    }
}

enum SceneSwitchTransition {
    case blur
    case freeze
    case blurAndZoom
}

struct CaptureDevice {
    let device: AVCaptureDevice
    let id: UUID
    let isVideoMirrored: Bool
}

struct CaptureDevices {
    var hasSceneDevice: Bool
    var devices: [CaptureDevice]
}

nonisolated(unsafe) var pixelFormatType = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
nonisolated(unsafe) var allowVideoRangePixelFormat = false
private let detectionsQueue = DispatchQueue(
    label: "com.haishinkit.HaishinKit.Detections",
    attributes: .concurrent
)

private func setOrientation(
    device: AVCaptureDevice?,
    isLandscapeStreamAndPortraitUi: Bool,
    connection: AVCaptureConnection,
    orientation: AVCaptureVideoOrientation
) {
    #if !targetEnvironment(macCatalyst)
    if #available(iOS 17.0, *), device?.deviceType == .external {
        connection.videoOrientation = .landscapeRight
    } else if useLandscapeStreamAndPortraitUi(device, isLandscapeStreamAndPortraitUi) {
        connection.videoOrientation = .portrait
    } else {
        connection.videoOrientation = orientation
    }
    #endif
}

struct TextDetection {
    let boundingBox: CGRect
}

struct Detections {
    let face: [VNFaceObservation]
    let text: [TextDetection]
}

class DetectionsCompletion: @unchecked Sendable {
    let sequenceNumber: UInt64
    let sampleBuffer: CMSampleBuffer
    let isFirstAfterAttach: Bool
    let isSceneSwitchTransition: Bool
    let sceneVideoSourceId: UUID
    let detectionJobs: [DetectionJob]
    var detections: [UUID: Detections]

    init(
        sequenceNumber: UInt64,
        sampleBuffer: CMSampleBuffer,
        isFirstAfterAttach: Bool,
        isSceneSwitchTransition: Bool,
        sceneVideoSourceId: UUID,
        detectionJobs: [DetectionJob]
    ) {
        self.sequenceNumber = sequenceNumber
        self.sampleBuffer = sampleBuffer
        self.isFirstAfterAttach = isFirstAfterAttach
        self.isSceneSwitchTransition = isSceneSwitchTransition
        self.sceneVideoSourceId = sceneVideoSourceId
        self.detectionJobs = detectionJobs
        detections = [:]
    }
}

private struct CaptureSessionDevice {
    let device: CaptureDevice
    let input: AVCaptureInput
    let output: AVCaptureVideoDataOutput
    let connection: AVCaptureConnection
    let photoOutput: AVCapturePhotoOutput?
    let photoConnection: AVCaptureConnection?

    func connections() -> [AVCaptureConnection] {
        if let photoConnection {
            [connection, photoConnection]
        } else {
            [connection]
        }
    }
}

private func makeCaptureSession() -> AVCaptureSession {
    let session = AVCaptureMultiCamSession()
    #if !targetEnvironment(macCatalyst)
    if session.isMultitaskingCameraAccessSupported {
        session.isMultitaskingCameraAccessEnabled = true
    }
    #endif
    return session
}

final class VideoUnit: NSObject, @unchecked Sendable {
    static let defaultFrameRate: Float64 = 30
    private var device: AVCaptureDevice?
    private var captureSessionDevices: [CaptureSessionDevice] = []
    private let effectsProcessor: VideoEffectsProcessor
    private let snapshots: VideoSnapshots
    private let lowFpsImage: VideoLowFpsImage
    private let fpsEstimator = VideoFpsEstimator()
    weak var drawable: PreviewView?
    weak var externalDisplayDrawable: PreviewView?
    private var videoPreviews: [UUID: PreviewView] = [:]
    private var videoPreviewEnabled = false
    private var nextDetectionsSequenceNumber: UInt64 = 0
    private var nextCompletedDetectionsSequenceNumber: UInt64 = 0
    private var completedDetections: [UInt64: DetectionsCompletion] = [:]
    private var captureSize = CGSize(width: 1920, height: 1080)
    var canvasSize: CGSize {
        get {
            effectsProcessor.canvasSize
        }
        set {
            effectsProcessor.canvasSize = newValue
        }
    }

    let session = makeCaptureSession()
    let encoder = VideoEncoder(lockQueue: processorPipelineQueue)
    var previewEncoder: VideoEncoder?
    weak var processor: Processor? {
        didSet {
            lowFpsImage.processor = processor
            fpsEstimator.processor = processor
        }
    }

    private var sceneVideoSourceId = UUID()
    private var selectedBufferedVideoCameraId: UUID?
    fileprivate var bufferedVideos: [UUID: BufferedVideo] = [:]
    fileprivate var bufferedVideoBuiltins: [AVCaptureDevice: BufferedVideo] = [:]
    private var blackImageBuffer: CVPixelBuffer?
    private var blackFormatDescription: CMVideoFormatDescription?
    private var blackPixelBufferPool: CVPixelBufferPool?
    private var latestSampleBuffer: CMSampleBuffer?
    private var sceneSwitchEndRendered = false
    private var frameTimer = SimpleTimer(queue: processorPipelineQueue)
    private var firstFrameTime: ContinuousClock.Instant?
    private var isFirstAfterAttach = false
    private var ignoreFramesAfterAttachSeconds = 0.0
    private var configuredIgnoreFramesAfterAttachSeconds = 0.0
    private var latestSampleBufferAppendTime: CMTime = .zero
    private var numberOfDiscardedFrames = 0
    private var cleanRecordings = false
    private var cleanExternalDisplay = false
    private var bufferedPool: CVPixelBufferPool?
    private var bufferedPoolFormatDescriptionExtension: CFDictionary?
    private var cameraControlsEnabled = false
    private var isRunning = false
    private var showCameraPreview = false
    private var screenPreviewEnabled = true
    private var externalDisplayPreview = false
    private var pixelTransferSession: VTPixelTransferSession?
    private var fps = VideoUnit.defaultFrameRate
    private var preferAutoFps = false
    private var colorSpace: AVCaptureColorSpace = .sRGB
    private var outputCounter: Int64 = -1
    private var startPresentationTimeStamp: CMTime = .zero
    private var isLandscapeStreamAndPortraitUi = false
    private var currentAttachParams: VideoUnitAttachParams?
    private var macScreenCaptureActive = false

    var videoOrientation: AVCaptureVideoOrientation = .portrait {
        didSet {
            guard videoOrientation != oldValue else {
                return
            }
            session.beginConfiguration()
            for device in captureSessionDevices {
                for connection in device.connections().filter(\.isVideoOrientationSupported) {
                    setOrientation(device: device.device.device,
                                   isLandscapeStreamAndPortraitUi: isLandscapeStreamAndPortraitUi,
                                   connection: connection,
                                   orientation: videoOrientation)
                }
            }
            session.commitConfiguration()
        }
    }

    var torch = false {
        didSet {
            guard let device else {
                if torch {
                    processor?.delegate.streamNoTorch()
                }
                return
            }
            setTorchMode(device, torch ? .on : .off)
        }
    }

    var torchLevel: Float = 1.0 {
        didSet {
            guard let device, torch else {
                return
            }
            setTorchMode(device, .on)
        }
    }

    override init() {
        let effectsProcessor = VideoEffectsProcessor()
        self.effectsProcessor = effectsProcessor
        snapshots = VideoSnapshots(context: effectsProcessor.context)
        lowFpsImage = VideoLowFpsImage(context: effectsProcessor.context)
        VTPixelTransferSessionCreate(allocator: nil, pixelTransferSessionOut: &pixelTransferSession)
        super.init()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleSessionRuntimeError),
                                               name: .AVCaptureSessionRuntimeError,
                                               object: session)
        startFrameTimer()
    }

    deinit {
        stopFrameTimer()
        #if targetEnvironment(macCatalyst)
        if #available(macCatalyst 18.2, *) {
            MacScreenCapture.shared.stop()
        }
        #endif
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
        fps
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
            self.effectsProcessor.registerEffect(effect)
        }
    }

    func registerEffectBack(_ effect: VideoEffect) {
        processorPipelineQueue.async {
            self.effectsProcessor.registerEffectBack(effect)
        }
    }

    func unregisterEffect(_ effect: VideoEffect) {
        processorPipelineQueue.async {
            self.effectsProcessor.unregisterEffect(effect)
        }
    }

    func unregisterAllEffects() {
        processorPipelineQueue.async {
            self.effectsProcessor.unregisterAllEffects()
        }
    }

    func setPendingAfterAttachEffects(effects: [VideoEffect], rotation: Double, mirror: Bool) {
        processorControlQueue.async {
            processorPipelineQueue.async {
                self.effectsProcessor.setPendingAfterAttachEffects(effects: effects,
                                                                   rotation: rotation,
                                                                   mirror: mirror)
            }
        }
    }

    func usePendingAfterAttachEffects() {
        processorControlQueue.async {
            processorPipelineQueue.async {
                self.effectsProcessor.usePendingAfterAttachEffects()
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

    func setVideoPreviewEnabled(enabled: Bool) {
        processorControlQueue.async {
            processorPipelineQueue.async {
                self.videoPreviewEnabled = enabled
            }
        }
    }

    func setVideoPreview(cameraId: UUID, drawable: PreviewView) {
        processorPipelineQueue.async {
            self.videoPreviews[cameraId] = drawable
        }
    }

    func removeAllVideoPreviews() {
        processorPipelineQueue.async {
            self.videoPreviews.removeAll()
        }
    }

    func setLowFpsImage(fps: Float) {
        processorPipelineQueue.async {
            self.lowFpsImage.setFps(fps: fps)
        }
    }

    func setSceneSwitchTransition(sceneSwitchTransition: SceneSwitchTransition) {
        processorPipelineQueue.async {
            self.effectsProcessor.sceneSwitchTransition = sceneSwitchTransition
        }
    }

    func takeSnapshot(age: Float, onComplete: @escaping @MainActor (UIImage, CIImage, CIImage) -> Void) {
        processorPipelineQueue.async {
            self.snapshots.takeSnapshot(age: age, onComplete: onComplete)
        }
    }

    func takeVideoSourceSnapshot(videoSourceId: UUID, onComplete: @escaping @MainActor (UIImage?) -> Void) {
        processorPipelineQueue.async {
            guard let sampleBuffer = self.bufferedVideos[videoSourceId]?.getLatestSampleBuffer(),
                  let imageBuffer = sampleBuffer.imageBuffer
            else {
                DispatchQueue.main.async { onComplete(nil) }
                return
            }
            self.snapshots.takeVideoSourceSnapshot(imageBuffer, onComplete)
        }
    }

    func takePhoto() {
        processorPipelineQueue.async {
            self.takePhotoInternal()
        }
    }

    func setCleanRecordings(enabled: Bool) {
        processorPipelineQueue.async {
            self.cleanRecordings = enabled
        }
    }

    func setCleanSnapshots(enabled: Bool) {
        processorPipelineQueue.async {
            self.snapshots.cleanSnapshots = enabled
        }
    }

    func setCleanExternalDisplay(enabled: Bool) {
        processorPipelineQueue.async {
            self.cleanExternalDisplay = enabled
        }
    }

    func appendBufferedVideoSampleBuffer(cameraId: UUID, _ sampleBuffer: CMSampleBuffer) {
        processorPipelineQueue.async {
            self.appendBufferedVideoSampleBufferInternal(cameraId: cameraId, sampleBuffer)
        }
    }

    func addBufferedVideo(cameraId: UUID, name: String, latency: Double, trackDrift: Bool = true) {
        processorPipelineQueue.async {
            self.addBufferedVideoInternal(cameraId: cameraId,
                                          name: name,
                                          latency: latency,
                                          trackDrift: trackDrift)
        }
    }

    func removeBufferedVideo(cameraId: UUID) {
        processorPipelineQueue.async {
            self.removeBufferedVideoInternal(cameraId: cameraId)
        }
    }

    func setBufferedVideoDrift(cameraId: UUID, drift: Double) {
        processorPipelineQueue.async {
            self.setBufferedVideoDriftInternal(cameraId: cameraId, drift: drift)
        }
    }

    func setBufferedVideoTargetLatency(cameraId: UUID, latency: Double) {
        processorPipelineQueue.async {
            self.setBufferedVideoTargetLatencyInternal(cameraId: cameraId, latency: latency)
        }
    }

    func startEncoding(_ delegate: any VideoEncoderDelegate) {
        encoder.delegate = delegate
        encoder.controlDelegate = self
        encoder.startRunning()
    }

    func stopEncoding() {
        encoder.stopRunning()
        processor?.delegate.streamVideoEncoderResolution(resolution: canvasSize)
    }

    func startPreviewEncoding(_ delegate: any VideoEncoderDelegate, settings: VideoEncoderSettings) {
        let encoder = VideoEncoder(lockQueue: processorPipelineQueue)
        encoder.settings.mutate { $0 = settings }
        encoder.delegate = delegate
        encoder.startRunning()
        previewEncoder = encoder
    }

    func stopPreviewEncoding() {
        previewEncoder?.stopRunning()
        previewEncoder = nil
    }

    func setSize(capture: CGSize, canvas: CGSize) {
        captureSize = capture
        canvasSize = canvas
        updateDevicesFormat()
        processorPipelineQueue.async {
            self.effectsProcessor.reset()
            self.bufferedPool = nil
        }
        processor?.delegate.streamVideoEncoderResolution(resolution: canvasSize)
    }

    func setGraphicsImplementation(value: SettingsGraphicsImplementation) {
        processorPipelineQueue.async {
            self.effectsProcessor.setGraphicsImplementation(value: value)
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

    func getMetalPetalImage(_ videoSourceId: UUID, _ presentationTimeStamp: CMTime) -> MTIImage? {
        guard let sampleBuffer = bufferedVideos[videoSourceId]?.getSampleBuffer(presentationTimeStamp),
              let imageBuffer = sampleBuffer.imageBuffer
        else {
            return nil
        }
        return MTIImage(cvPixelBuffer: imageBuffer, alphaType: .alphaIsOne)
    }

    func attach(params: VideoUnitAttachParams) throws {
        if currentAttachParams?.canQuickSwitchTo(other: params) == true {
            attachQuickSwitch(params: params)
        } else {
            try attachDefault(params: params)
        }
        currentAttachParams = params
    }

    private func attachQuickSwitch(params: VideoUnitAttachParams) {
        processorPipelineQueue.async {
            self.selectedBufferedVideoCameraId = params.bufferedVideo
            self.isFirstAfterAttach = true
            self.externalDisplayPreview = params.externalDisplayPreview
            self.effectsProcessor.fillFrame = params.fillFrame
            if let bufferedVideo = params.bufferedVideo {
                self.sceneVideoSourceId = bufferedVideo
            } else if params.devices.hasSceneDevice, let id = params.devices.devices.first?.id {
                self.sceneVideoSourceId = id
            } else {
                self.sceneVideoSourceId = UUID()
            }
            self.effectsProcessor.prepareForAttach()
        }
    }

    private func attachDefault(params: VideoUnitAttachParams) throws {
        updateMacScreenCapture(enabled: params.macScreenCapture)
        for device in captureSessionDevices {
            device.output.setSampleBufferDelegate(nil, queue: processorPipelineQueue)
        }
        processorPipelineQueue.async {
            self.configuredIgnoreFramesAfterAttachSeconds = params.ignoreFramesAfterAttachSeconds
            self.selectedBufferedVideoCameraId = params.bufferedVideo
            self.prepareFirstFrame()
            self.showCameraPreview = params.showCameraPreview
            self.externalDisplayPreview = params.externalDisplayPreview
            self.effectsProcessor.fillFrame = params.fillFrame
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
                    name: device.device.localizedName,
                    update: false,
                    latency: params.builtinDelay,
                    processor: self.processor
                )
                self.bufferedVideos[device.id] = bufferedVideo
                self.bufferedVideoBuiltins[device.device] = bufferedVideo
            }
            self.effectsProcessor.prepareForAttach()
        }
        isLandscapeStreamAndPortraitUi = params.isLandscapeStreamAndPortraitUi
        for device in params.devices.devices {
            setDeviceFormat(
                device: device.device,
                fps: fps,
                preferAutoFrameRate: preferAutoFps,
                colorSpace: colorSpace
            )
        }
        try configureCaptureSession(params: params)
        // FPS must be set after starting the capture session.
        updateDevicesFormat()
    }

    private func configureCaptureSession(params: VideoUnitAttachParams) throws {
        session.beginConfiguration()
        defer {
            session.commitConfiguration()
        }
        removeDevices(session)
        for device in params.devices.devices {
            try attachDevice(device, session, params.photoShoot)
        }
        session.automaticallyConfiguresCaptureDeviceForWideColor = false
        device = params.devices.hasSceneDevice ? params.devices.devices.first?.device : nil
        for device in captureSessionDevices {
            for connection in device.output.connections {
                if connection.isVideoMirroringSupported {
                    connection.isVideoMirrored = device.device.isVideoMirrored
                }
                if connection.isVideoStabilizationSupported {
                    connection.preferredVideoStabilizationMode = params.preferredVideoStabilizationMode
                }
            }
            for connection in device.connections() where connection.isVideoOrientationSupported {
                setOrientation(device: device.device.device,
                               isLandscapeStreamAndPortraitUi: isLandscapeStreamAndPortraitUi,
                               connection: connection,
                               orientation: videoOrientation)
            }
        }
        for device in captureSessionDevices {
            device.output.setSampleBufferDelegate(self, queue: processorPipelineQueue)
        }
        updateCameraControls()
        params.cameraPreviewLayer.session = nil
        if params.showCameraPreview {
            params.cameraPreviewLayer.session = session
        }
    }

    private func updateMacScreenCapture(enabled: Bool) {
        #if targetEnvironment(macCatalyst)
        if #available(macCatalyst 18.2, *) {
            if enabled, !macScreenCaptureActive {
                macScreenCaptureActive = true
                MacScreenCapture.shared.delegate = self
                MacScreenCapture.shared.start(fps: fps)
            } else if !enabled, macScreenCaptureActive {
                macScreenCaptureActive = false
                MacScreenCapture.shared.stop()
            }
        }
        #endif
    }

    @objc
    private func handleSessionRuntimeError(_ notification: NSNotification) {
        guard let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError else {
            return
        }
        let message = error._nsError.localizedFailureReason ?? "\(error.code)"
        processor?.delegate.streamVideoCaptureSessionError(message)
        processorControlQueue.asyncAfter(deadline: .now() + .milliseconds(500)) {
            if self.isRunning {
                self.session.startRunning()
            }
        }
    }

    private func updateDevicesFormat() {
        for device in captureSessionDevices {
            setDeviceFormat(
                device: device.device.device,
                fps: fps,
                preferAutoFrameRate: preferAutoFps,
                colorSpace: colorSpace
            )
        }
    }

    private func setBufferedVideoDriftInternal(cameraId: UUID, drift: Double) {
        bufferedVideos[cameraId]?.setDrift(drift: drift)
    }

    private func setBufferedVideoTargetLatencyInternal(cameraId: UUID, latency: Double) {
        bufferedVideos[cameraId]?.setTargetLatency(latency: latency)
    }

    private func startFrameTimer() {
        let frameInterval = 1 / fps
        outputCounter = -1
        startPresentationTimeStamp = .zero
        frameTimer.startPeriodic(interval: frameInterval) { [weak self] in
            self?.handleFrameTimer()
        }
    }

    private func stopFrameTimer() {
        frameTimer.stop()
    }

    private func makePresentationTimeStamp() -> CMTime {
        CMTime(value: outputCounter, timescale: Int32(fps)) + startPresentationTimeStamp
    }

    private func handleFrameTimer() {
        outputCounter += 1
        let currentPresentationTimeStamp = currentPresentationTimeStamp()
        if startPresentationTimeStamp == .zero {
            startPresentationTimeStamp = currentPresentationTimeStamp
        }
        var presentationTimeStamp = makePresentationTimeStamp()
        let deltaFromCalculatedToClock = presentationTimeStamp - currentPresentationTimeStamp
        if abs(deltaFromCalculatedToClock.seconds) > deltaLimit {
            if deltaFromCalculatedToClock > .zero {
                logger.info("""
                video-unit: Adjust PTS back in time. Calculated is \
                \(presentationTimeStamp.seconds) \
                and clock is \(currentPresentationTimeStamp.seconds)
                """)
                outputCounter -= 1
            } else {
                logger.info("""
                video-unit: Adjust PTS forward in time. Calculated is \
                \(presentationTimeStamp.seconds) \
                and clock is \(currentPresentationTimeStamp.seconds)
                """)
                outputCounter += 1
            }
            presentationTimeStamp = makePresentationTimeStamp()
        }
        handleBufferedVideo(presentationTimeStamp)
        handleGapFillerTimer()
    }

    private func handleBufferedVideo(_ presentationTimeStamp: CMTime) {
        for (cameraId, bufferedVideo) in bufferedVideos {
            bufferedVideo.updateSampleBuffer(presentationTimeStamp.seconds)
            if videoPreviewEnabled,
               let sampleBuffer = bufferedVideo.getSampleBuffer(presentationTimeStamp)
            {
                enqueueVideoPreviewForBufferedVideo(cameraId: cameraId, sampleBuffer: sampleBuffer)
            }
        }
        guard let selectedBufferedVideoCameraId else {
            return
        }
        for bufferedVideoBuiltin in bufferedVideoBuiltins.values where bufferedVideoBuiltin.latency > 0 {
            bufferedVideoBuiltin.updateSampleBuffer(presentationTimeStamp.seconds, true)
        }
        if let sampleBuffer = bufferedVideos[selectedBufferedVideoCameraId]?
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
            logger.info("video-unit: Failed to output buffered frame")
        }
    }

    private func handleGapFillerTimer() {
        guard isFirstAfterAttach else {
            return
        }
        guard var latestSampleBuffer, let latestSampleBufferTime = effectsProcessor.latestSampleBufferTime
        else {
            return
        }
        let delta = latestSampleBufferTime.duration(to: .now)
        guard delta > .seconds(0.05) else {
            return
        }
        let isSceneSwitchTransition = !effectsProcessor.isAtEndOfSceneSwitchTransition()
        if !isSceneSwitchTransition, !sceneSwitchEndRendered {
            latestSampleBuffer = renderSceneSwitchTransitionEnd(sampleBuffer: latestSampleBuffer)
            self.latestSampleBuffer = latestSampleBuffer
            sceneSwitchEndRendered = true
        }
        let timeDelta = CMTime(seconds: delta.seconds)
        let newPresentationTimeStamp = latestSampleBuffer.presentationTimeStamp + timeDelta
        guard let sampleBuffer = latestSampleBuffer.replacePresentationTimeStamp(newPresentationTimeStamp)
        else {
            return
        }
        _ = appendSampleBuffer(
            sampleBuffer,
            isFirstAfterAttach: false,
            isSceneSwitchTransition: isSceneSwitchTransition
        )
    }

    private func renderSceneSwitchTransitionEnd(sampleBuffer: CMSampleBuffer) -> CMSampleBuffer {
        guard let imageBuffer = sampleBuffer.imageBuffer else {
            return sampleBuffer
        }
        guard let outputImageBuffer = createBufferedPixelBuffer(sampleBuffer: sampleBuffer) else {
            return sampleBuffer
        }
        return effectsProcessor.renderSceneSwitchTransitionEnd(sampleBuffer, imageBuffer, outputImageBuffer)
    }

    private func prepareFirstFrame() {
        firstFrameTime = nil
        isFirstAfterAttach = true
        ignoreFramesAfterAttachSeconds = configuredIgnoreFramesAfterAttachSeconds
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
        attributes[kCVPixelBufferWidthKey] = NSNumber(value: formatDescription.dimensions.width)
        attributes[kCVPixelBufferHeightKey] = NSNumber(value: formatDescription.dimensions.height)
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

    private func takePhotoInternal() {
        for device in captureSessionDevices {
            guard let photoOutput = device.photoOutput else {
                continue
            }
            let settings = AVCapturePhotoSettings()
            settings.maxPhotoDimensions = photoOutput.maxPhotoDimensions
            settings.photoQualityPrioritization = .balanced
            if #available(iOS 18, *) {
                settings.isShutterSoundSuppressionEnabled = true
            }
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    private func appendBufferedVideoSampleBufferInternal(cameraId: UUID, _ sampleBuffer: CMSampleBuffer) {
        guard let bufferedVideo = bufferedVideos[cameraId] else {
            return
        }
        bufferedVideo.appendSampleBuffer(sampleBuffer)
    }

    private func addBufferedVideoInternal(cameraId: UUID,
                                          name: String,
                                          latency: Double,
                                          trackDrift: Bool = true)
    {
        bufferedVideos[cameraId] = BufferedVideo(
            cameraId: cameraId,
            name: name,
            update: true,
            latency: latency,
            processor: processor,
            trackDrift: trackDrift
        )
    }

    private func removeBufferedVideoInternal(cameraId: UUID) {
        bufferedVideos.removeValue(forKey: cameraId)
    }

    private func makeBlackSampleBuffer(
        duration: CMTime,
        presentationTimeStamp: CMTime,
        decodeTimeStamp: CMTime
    ) -> CMSampleBuffer? {
        if blackImageBuffer == nil || blackFormatDescription == nil {
            let width = canvasSize.width
            let height = canvasSize.height
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
        guard sampleBuffer.presentationTimeStamp > latestSampleBufferAppendTime else {
            numberOfDiscardedFrames += 1
            return false
        }
        if numberOfDiscardedFrames > 0 {
            logger.info(
                """
                video-unit: Discarded \(numberOfDiscardedFrames) old frames before \
                \(sampleBuffer.presentationTimeStamp.seconds)
                """
            )
            numberOfDiscardedFrames = 0
        }
        latestSampleBufferAppendTime = sampleBuffer.presentationTimeStamp
        let presentationTimeStamp = sampleBuffer.presentationTimeStamp.seconds
        fpsEstimator.update(presentationTimeStamp, fps)
        let detectionJobs = prepareDetectionJobs(
            effectsProcessor.needsFaceDetections(presentationTimeStamp, sceneVideoSourceId),
            effectsProcessor.needsTextDetections(presentationTimeStamp, sceneVideoSourceId),
            sampleBuffer.presentationTimeStamp,
            imageBuffer
        )
        let completion = DetectionsCompletion(
            sequenceNumber: nextDetectionsSequenceNumber,
            sampleBuffer: sampleBuffer,
            isFirstAfterAttach: isFirstAfterAttach,
            isSceneSwitchTransition: isSceneSwitchTransition,
            sceneVideoSourceId: sceneVideoSourceId,
            detectionJobs: detectionJobs
        )
        nextDetectionsSequenceNumber += 1
        if !detectionJobs.isEmpty {
            for detectionJob in detectionJobs {
                detectionsQueue.async {
                    self.detectObjects(detectionJob: detectionJob, completion: completion)
                }
            }
        } else {
            detectObjectsComplete(completion)
        }
        return true
    }

    private func detectObjects(detectionJob: DetectionJob, completion: DetectionsCompletion) {
        nonisolated(unsafe)
        var faceDetections: [VNFaceObservation] = []
        nonisolated(unsafe)
        var textDetections: [TextDetection] = []
        var faceLandmarksRequest: VNDetectFaceLandmarksRequest?
        var textRequest: VNRecognizeTextRequest?
        var requests: [VNRequest] = []
        if detectionJob.detectFaces {
            faceLandmarksRequest = VNDetectFaceLandmarksRequest()
            requests.append(faceLandmarksRequest!)
        }
        if detectionJob.detectText {
            textRequest = VNRecognizeTextRequest()
            textRequest!.recognitionLevel = .fast
            textRequest!.usesLanguageCorrection = false
            textRequest!.minimumTextHeight = 0.05
            requests.append(textRequest!)
        }
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: detectionJob.imageBuffer)
        if (try? imageRequestHandler.perform(requests)) != nil {
            if let results = faceLandmarksRequest?
                .results?
                .sorted(by: { $0.boundingBox.height > $1.boundingBox.height })
                .prefix(5)
            {
                faceDetections += results
            }
            if let results = textRequest?.results {
                for result in results
                    .sorted(by: { $0.boundingBox.height > $1.boundingBox.height })
                    .prefix(10)
                {
                    if let text = result.topCandidates(1).first, text.confidence >= 0.5 {
                        textDetections.append(TextDetection(boundingBox: result.boundingBox))
                    }
                }
            }
        }
        processorPipelineQueue.async {
            completion.detections[detectionJob.videoSourceId] = Detections(
                face: faceDetections,
                text: textDetections
            )
            self.detectObjectsComplete(completion)
        }
    }

    private func detectObjectsComplete(_ completion: DetectionsCompletion) {
        guard completion.detections.count == completion.detectionJobs.count else {
            return
        }
        completedDetections[completion.sequenceNumber] = completion
        while let completion = completedDetections
            .removeValue(forKey: nextCompletedDetectionsSequenceNumber)
        {
            appendSampleBufferWithDetections(completion)
            nextCompletedDetectionsSequenceNumber += 1
        }
    }

    private func appendSampleBufferWithDetections(_ completion: DetectionsCompletion) {
        let sampleBuffer = completion.sampleBuffer
        guard let imageBuffer = sampleBuffer.imageBuffer else {
            return
        }
        let (modImageBuffer, modSampleBuffer) = effectsProcessor.render(
            imageBuffer,
            completion,
            self,
            videoOrientation
        )
        if cleanRecordings {
            processor?.recorder.appendVideo(sampleBuffer)
        } else {
            processor?.recorder.appendVideo(modSampleBuffer)
        }
        modSampleBuffer.setAttachmentDisplayImmediately()
        let isFirstAfterAttach = completion.isFirstAfterAttach
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
        previewEncoder?.encodeImageBuffer(
            modImageBuffer,
            presentationTimeStamp: modSampleBuffer.presentationTimeStamp,
            duration: modSampleBuffer.duration
        )
        let presentationTimeStamp = sampleBuffer.presentationTimeStamp.seconds
        lowFpsImage.handleImageBuffer(modImageBuffer, presentationTimeStamp)
        if snapshots.cleanSnapshots {
            snapshots.handleTakeSnapshot(sampleBuffer, presentationTimeStamp, makeCopy(sampleBuffer:))
        } else {
            snapshots.handleTakeSnapshot(modSampleBuffer, presentationTimeStamp, makeCopy(sampleBuffer:))
        }
    }

    private func prepareDetectionJobs(
        _ faceDetectionVideoSourceIds: Set<UUID>,
        _ textDetectionVideoSourceIds: Set<UUID>,
        _ presentationTimeStamp: CMTime,
        _ imageBuffer: CVImageBuffer
    ) -> [DetectionJob] {
        var detectionJobs: [DetectionJob] = []
        for videoSourceId in faceDetectionVideoSourceIds.union(textDetectionVideoSourceIds) {
            let videoSourceImageBuffer: CVPixelBuffer? = if videoSourceId == sceneVideoSourceId {
                imageBuffer
            } else {
                bufferedVideos[videoSourceId]?
                    .getSampleBuffer(presentationTimeStamp)?
                    .imageBuffer
            }
            guard let videoSourceImageBuffer else {
                detectionJobs.removeAll()
                break
            }
            detectionJobs.append(DetectionJob(videoSourceId: videoSourceId,
                                              imageBuffer: videoSourceImageBuffer,
                                              detectFaces: faceDetectionVideoSourceIds
                                                  .contains(videoSourceId),
                                              detectText: textDetectionVideoSourceIds
                                                  .contains(videoSourceId)))
        }
        return detectionJobs
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
        logger.debug("video-unit: Session interruption started")
        processorPipelineQueue.async {
            self.prepareFirstFrame()
        }
    }

    @objc
    private func sessionInterruptionEnded(_: Notification) {
        logger.debug("video-unit: Session interruption ended")
    }

    private func findVideoFormat(
        device: AVCaptureDevice,
        width: Int32,
        height: Int32,
        fps: Float64,
        preferAutoFrameRate: Bool,
        colorSpace: AVCaptureColorSpace
    ) -> (AVCaptureDevice.Format?, Bool, Bool, String?) {
        var useAutoFrameRate = false
        var useLandscapeInPortrait = false
        var formats = device.formats
        formats = formats.filter { $0.isFrameRateSupported(fps) }
        if #available(iOS 18, *), preferAutoFrameRate {
            let autoFrameRateFormats = formats.filter(\.isAutoVideoFrameRateSupported)
            if !autoFrameRateFormats.isEmpty {
                formats = autoFrameRateFormats
                useAutoFrameRate = true
            }
        }
        formats = formats.filter { $0.formatDescription.dimensions.width == width }
        if #available(iOS 26, *), isLandscapeStreamAndPortraitUi {
            #if targetEnvironment(macCatalyst)
            let formatsWithRatio9x16: [AVCaptureDevice.Format] = []
            #else
            let formatsWithRatio9x16 = formats.filter { $0.supportedDynamicAspectRatios.contains(.ratio9x16) }
            #endif
            if !formatsWithRatio9x16.isEmpty {
                formats = formatsWithRatio9x16
                useLandscapeInPortrait = true
            } else {
                formats = formats.filter { $0.formatDescription.dimensions.height == height }
            }
        } else {
            formats = formats.filter { $0.formatDescription.dimensions.height == height }
        }
        formats = formats.filter { $0.supportedColorSpaces.contains(colorSpace) }
        if formats.isEmpty {
            return (
                nil,
                useAutoFrameRate,
                useLandscapeInPortrait,
                "No format found matching \(height)p\(Int(fps)), \(colorSpace)"
            )
        }
        formats = formats.filter { !$0.isVideoBinned }
        if formats.isEmpty {
            return (nil, useAutoFrameRate, useLandscapeInPortrait, "No unbinned video format found")
        }
        // 420v does not work with OA4.
        formats = formats.filter {
            $0.formatDescription.mediaSubType.rawValue != kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
                || allowVideoRangePixelFormat
        }
        if formats.isEmpty {
            return (nil, useAutoFrameRate, useLandscapeInPortrait, "Unsupported pixel format")
        }
        return (formats.first, useAutoFrameRate, useLandscapeInPortrait, nil)
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
        logger.info("video-unit: \(error)")
        logger.info("video-unit: \(activeFormat)")
        for format in device.formats {
            logger.info("video-unit: Available format: \(format)")
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
        let (format, useAutoFrameRate, useLandscapeInPortrait, error) = findVideoFormat(
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
        logger.debug("video-unit: Selected format: \(format)")
        do {
            try device.lockForConfiguration()
            if device.activeFormat != format {
                device.activeFormat = format
            }
            device.activeColorSpace = colorSpace
            if useAutoFrameRate {
                device.setAutoFps()
                processor?.delegate.streamSelectedFps(auto: true)
            } else {
                device.setFps(frameRate: fps)
                processor?.delegate.streamSelectedFps(auto: false)
            }
            if #available(iOS 26, *), useLandscapeInPortrait {
                #if !targetEnvironment(macCatalyst)
                if format.supportedDynamicAspectRatios.contains(.ratio9x16) {
                    device.setDynamicAspectRatio(.ratio9x16)
                }
                #endif
            }
            device.unlockForConfiguration()
        } catch {
            logger.info("video-unit: Error while locking device: \(error)")
        }
    }

    private func attachDevice(_ device: CaptureDevice,
                              _ session: AVCaptureSession,
                              _ photoShoot: Bool) throws
    {
        let input = try AVCaptureDeviceInput(device: device.device)
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
        var photoOutput: AVCapturePhotoOutput?
        var photoConnection: AVCaptureConnection?
        if photoShoot {
            photoOutput = AVCapturePhotoOutput()
            if let port = input.ports.first(where: { $0.mediaType == .video }) {
                photoConnection = AVCaptureConnection(inputPorts: [port], output: photoOutput!)
            }
            if session.canAddOutput(photoOutput!) {
                session.addOutputWithNoConnections(photoOutput!)
            } else {
                failed = true
            }
            if let photoConnection, session.canAddConnection(photoConnection) {
                session.addConnection(photoConnection)
            } else {
                failed = true
            }
            photoOutput!.maxPhotoDimensions = device.device.activeFormat.supportedMaxPhotoDimensions.last!
            photoOutput!.maxPhotoQualityPrioritization = .balanced
        }
        if failed {
            processor?.delegate.streamVideoAttachCameraError()
        } else {
            captureSessionDevices.append(CaptureSessionDevice(
                device: device,
                input: input,
                output: output,
                connection: connection!,
                photoOutput: photoOutput,
                photoConnection: photoConnection
            ))
        }
    }

    private func removeDevices(_ session: AVCaptureSession) {
        for device in captureSessionDevices {
            removeConnection(session, device.connection)
            removeInput(session, device.input)
            removeOutput(session, device.output)
        }
        captureSessionDevices.removeAll()
    }

    private func removeConnection(_ session: AVCaptureSession, _ connection: AVCaptureConnection?) {
        if let connection, session.connections.contains(connection) {
            session.removeConnection(connection)
        }
    }

    private func removeInput(_ session: AVCaptureSession, _ input: AVCaptureInput?) {
        if let input, session.inputs.contains(input) {
            session.removeInput(input)
        }
    }

    private func removeOutput(_ session: AVCaptureSession, _ output: AVCaptureOutput?) {
        if let output, session.outputs.contains(output) {
            session.removeOutput(output)
        }
    }

    private func setTorchMode(_ device: AVCaptureDevice, _ torchMode: AVCaptureDevice.TorchMode) {
        guard device.isTorchModeSupported(torchMode) else {
            if torchMode == .on {
                processor?.delegate.streamNoTorch()
            }
            return
        }
        do {
            try device.lockForConfiguration()
            if torchMode == .on {
                try device.setTorchModeOn(level: torchLevel.clamped(to: 0.01 ... 1.0))
            } else {
                device.torchMode = torchMode
            }
            device.unlockForConfiguration()
        } catch {
            logger.info("video-unit: Error while setting torch: \(error)")
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
        effectsProcessor.latestSampleBufferTime = now
        sceneSwitchEndRendered = false
        if appendSampleBuffer(
            sampleBuffer,
            isFirstAfterAttach: isFirstAfterAttach,
            isSceneSwitchTransition: false
        ) {
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
        let displayVideoZoomFactorMultiplier = device.displayVideoZoomFactorMultiplier
        let zoomSlider = AVCaptureSystemZoomSlider(device: device) { [weak self] zoomFactor in
            let x = Float(displayVideoZoomFactorMultiplier * zoomFactor)
            self?.processor?.delegate.streamSetZoomX(x: x)
        }
        if session.canAddControl(zoomSlider) {
            session.addControl(zoomSlider)
        }
        let exposureBiasSlider =
            AVCaptureSystemExposureBiasSlider(device: device) { [weak self] exposureBias in
                self?.processor?.delegate.streamSetExposureBias(bias: exposureBias)
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
        var sampleBufferCopy: CMSampleBuffer = if bufferedVideo.numberOfBuffers() > 4 {
            makeCopy(sampleBuffer: sampleBuffer) ?? sampleBuffer
        } else {
            sampleBuffer
        }
        let presentationTimeStamp = sampleBufferCopy
            .presentationTimeStamp + CMTime(seconds: bufferedVideo.latency)
        sampleBufferCopy = sampleBufferCopy
            .replacePresentationTimeStamp(presentationTimeStamp) ?? sampleBufferCopy
        bufferedVideo.appendSampleBuffer(sampleBufferCopy)
        return bufferedVideo
    }

    private func isSceneVideoSource(device: AVCaptureDevice) -> Bool {
        captureSessionDevices.first(where: { $0.device.device == device })?.device
            .id == sceneVideoSourceId
    }

    private func enqueueVideoPreview(device: AVCaptureDevice, sampleBuffer: CMSampleBuffer) {
        guard let captureDevice = captureSessionDevices.first(where: { $0.device.device == device }) else {
            return
        }
        guard let drawable = videoPreviews[captureDevice.device.id] else {
            return
        }
        sampleBuffer.setAttachmentDisplayImmediately()
        drawable.enqueue(sampleBuffer, isFirstAfterAttach: false)
    }

    private func enqueueVideoPreviewForBufferedVideo(cameraId: UUID, sampleBuffer: CMSampleBuffer) {
        guard let drawable = videoPreviews[cameraId] else {
            return
        }
        sampleBuffer.setAttachmentDisplayImmediately()
        drawable.enqueue(sampleBuffer, isFirstAfterAttach: false)
    }
}

// private var baseTimestamp: Double = .nan
// private var previousTimestamp: Double = 0.0
// private var nowStart: ContinuousClock.Instant?

extension VideoUnit: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let input = connection.inputPorts.first?.input as? AVCaptureDeviceInput else {
            return
        }
        // if baseTimestamp.isNaN {
        //     baseTimestamp = sampleBuffer.presentationTimeStamp.seconds
        // }
        // if nowStart == nil {
        //     nowStart = .now
        // }
        // let timestamp = sampleBuffer.presentationTimeStamp.seconds - baseTimestamp
        // let delta = timestamp - previousTimestamp
        // let hostTime = currentPresentationTimeStamp().seconds - baseTimestamp
        // let now = nowStart!.duration(to: .now).seconds
        // logger.info("""
        // xxx video \
        // t: \(formatFourDecimals(timestamp)) \
        // d: \(formatFourDecimals(delta)) \
        // h: \(formatFourDecimals(hostTime)) n: \(formatFourDecimals(now))
        // """)
        // if delta > 0.04 || delta < 0.02 {
        //     logger.info("""
        //     xxx video abnormal \
        //     t: \(formatFourDecimals(timestamp)) \
        //     d: \(formatFourDecimals(delta)) \
        //     h: \(formatFourDecimals(hostTime)) n: \(formatFourDecimals(now))
        //     """)
        // }
        // previousTimestamp = timestamp
        if videoPreviewEnabled {
            enqueueVideoPreview(device: input.device, sampleBuffer: sampleBuffer)
        }
        if isSceneVideoSource(device: input.device) {
            var sampleBuffer = sampleBuffer
            if let bufferedVideo = appendBufferedBuiltinVideo(sampleBuffer, input.device) {
                for bufferedVideoBuiltin in bufferedVideoBuiltins.values {
                    bufferedVideoBuiltin.updateSampleBuffer(sampleBuffer.presentationTimeStamp.seconds, true)
                }
                sampleBuffer = bufferedVideo
                    .getSampleBuffer(sampleBuffer.presentationTimeStamp) ?? sampleBuffer
            }
            guard selectedBufferedVideoCameraId == nil else {
                return
            }
            appendNewSampleBuffer(sampleBuffer: sampleBuffer)
        } else {
            _ = appendBufferedBuiltinVideo(sampleBuffer, input.device)
        }
    }
}

func createBlackImage(width: Double, height: Double) -> CIImage {
    CIImage.black.cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
}

@available(iOS 18.0, *)
extension VideoUnit: AVCaptureSessionControlsDelegate {
    func sessionControlsDidBecomeActive(_: AVCaptureSession) {}

    func sessionControlsWillEnterFullscreenAppearance(_: AVCaptureSession) {}

    func sessionControlsWillExitFullscreenAppearance(_: AVCaptureSession) {}

    func sessionControlsDidBecomeInactive(_: AVCaptureSession) {}
}

extension VideoUnit: VideoEncoderControlDelegate {
    func videoEncoderControlResolutionChanged(_: VideoEncoder, resolution: CGSize) {
        processor?.delegate.streamVideoEncoderResolution(resolution: resolution)
    }
}

#if targetEnvironment(macCatalyst)
@available(macCatalyst 18.2, *)
extension VideoUnit: MacScreenCaptureDelegate {
    func macScreenCaptureDidStart(latency: Double) {
        addBufferedVideo(
            cameraId: screenCaptureCameraId,
            name: screenCaptureCameraName,
            latency: latency,
            trackDrift: false
        )
    }

    func macScreenCaptureDidStop() {
        removeBufferedVideo(cameraId: screenCaptureCameraId)
    }

    func macScreenCaptureDidOutputSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        appendBufferedVideoSampleBufferInternal(cameraId: screenCaptureCameraId, sampleBuffer)
    }
}
#endif

extension VideoUnit: AVCapturePhotoCaptureDelegate {
    func photoOutput(_: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            logger.info("video-unit: Photo error: \(error)")
            return
        }
        if let photoData = photo.fileDataRepresentation() {
            PHPhotoLibrary.shared().performChanges {
                let creationRequest = PHAssetCreationRequest.forAsset()
                creationRequest.addResource(with: .photo, data: photoData, options: nil)
            } completionHandler: { _, error in
                if let error {
                    logger.info("video-unit: Error saving photo: \(error.localizedDescription)")
                    return
                }
            }
        }
    }
}
