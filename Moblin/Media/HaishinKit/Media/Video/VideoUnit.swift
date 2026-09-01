import AVFoundation
import CoreImage
import MetalPetal
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
    let cameraPreviewLayers: [UUID: AVCaptureVideoPreviewLayer]
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
        if showCameraPreview != other.showCameraPreview {
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

nonisolated(unsafe) var pixelFormatType = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
nonisolated(unsafe) var allowVideoRangePixelFormat = false
private let detectionsQueue = DispatchQueue(
    label: "com.haishinkit.HaishinKit.Detections",
    attributes: .concurrent
)

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

final class VideoUnit: NSObject, @unchecked Sendable {
    static let defaultFrameRate: Float64 = 30
    private let captureSession = VideoCaptureSession()
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
    var canvasSize: CGSize {
        get {
            effectsProcessor.canvasSize
        }
        set {
            effectsProcessor.canvasSize = newValue
        }
    }

    let encoder = VideoEncoder(lockQueue: processorPipelineQueue)
    var previewEncoder: VideoEncoder?
    weak var processor: Processor? {
        didSet {
            captureSession.processor = processor
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
    private var showCameraPreview = false
    private var screenPreviewEnabled = true
    private var externalDisplayPreview = false
    private var pixelTransferSession: VTPixelTransferSession?
    private var outputCounter: Int64 = -1
    private var startPresentationTimeStamp: CMTime = .zero
    private var currentAttachParams: VideoUnitAttachParams?
    private var macScreenCaptureActive = false

    var videoOrientation: AVCaptureVideoOrientation {
        get {
            captureSession.videoOrientation
        }
        set {
            captureSession.videoOrientation = newValue
        }
    }

    var torch: Bool {
        get {
            captureSession.torch
        }
        set {
            captureSession.torch = newValue
        }
    }

    var torchLevel: Float {
        get {
            captureSession.torchLevel
        }
        set {
            captureSession.torchLevel = newValue
        }
    }

    override init() {
        let effectsProcessor = VideoEffectsProcessor()
        self.effectsProcessor = effectsProcessor
        snapshots = VideoSnapshots(context: effectsProcessor.context)
        lowFpsImage = VideoLowFpsImage(context: effectsProcessor.context)
        VTPixelTransferSessionCreate(allocator: nil, pixelTransferSessionOut: &pixelTransferSession)
        super.init()
        captureSession.delegate = self
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
        captureSession.startRunning()
    }

    func stopRunning() {
        captureSession.stopRunning()
    }

    func setFps(fps: Float64, preferAutoFps: Bool) {
        captureSession.setFps(fps: fps, preferAutoFps: preferAutoFps)
        startFrameTimer()
    }

    func getFps() -> Double {
        captureSession.getFps()
    }

    func setColorSpace(colorSpace: AVCaptureColorSpace) {
        captureSession.setColorSpace(colorSpace: colorSpace)
    }

    func setCameraControl(enabled: Bool) {
        captureSession.setCameraControl(enabled: enabled)
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
            self.captureSession.takePhoto()
        }
    }

    func setCleanRecordings(enabled: Bool) {
        processorPipelineQueue.async {
            self.cleanRecordings = enabled
        }
    }

    func setCleanSnapshots(enabled: Bool) {
        processorPipelineQueue.async {
            self.snapshots.setCleanSnapshots(enabled: enabled)
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

    func addBufferedVideo(cameraId: UUID, name: String, latency: Double, trackDrift: Bool) {
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
        canvasSize = canvas
        captureSession.setCaptureSize(capture)
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
        captureSession.stopOutputtingSampleBuffers()
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
                    processor: self.processor, trackDrift: true
                )
                self.bufferedVideos[device.id] = bufferedVideo
                self.bufferedVideoBuiltins[device.device] = bufferedVideo
            }
            self.effectsProcessor.prepareForAttach()
        }
        try captureSession.attach(params: params)
    }

    private func updateMacScreenCapture(enabled: Bool) {
        #if targetEnvironment(macCatalyst)
        if #available(macCatalyst 18.2, *) {
            if enabled, !macScreenCaptureActive {
                macScreenCaptureActive = true
                MacScreenCapture.shared.delegate = self
                MacScreenCapture.shared.start(fps: captureSession.getFps())
            } else if !enabled, macScreenCaptureActive {
                macScreenCaptureActive = false
                MacScreenCapture.shared.stop()
            }
        }
        #endif
    }

    private func setBufferedVideoDriftInternal(cameraId: UUID, drift: Double) {
        bufferedVideos[cameraId]?.setDrift(drift: drift)
    }

    private func setBufferedVideoTargetLatencyInternal(cameraId: UUID, latency: Double) {
        bufferedVideos[cameraId]?.setTargetLatency(latency: latency)
    }

    private func startFrameTimer() {
        let frameInterval = 1 / captureSession.getFps()
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
        CMTime(value: outputCounter, timescale: Int32(captureSession.getFps())) + startPresentationTimeStamp
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
                enqueueVideoPreview(cameraId: cameraId, sampleBuffer: sampleBuffer)
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

    private func appendBufferedVideoSampleBufferInternal(cameraId: UUID, _ sampleBuffer: CMSampleBuffer) {
        guard let bufferedVideo = bufferedVideos[cameraId] else {
            return
        }
        bufferedVideo.appendSampleBuffer(sampleBuffer)
    }

    private func addBufferedVideoInternal(cameraId: UUID,
                                          name: String,
                                          latency: Double,
                                          trackDrift: Bool)
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
        fpsEstimator.update(presentationTimeStamp, captureSession.getFps())
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
        snapshots.handleTakeSnapshot(
            sampleBuffer,
            modSampleBuffer,
            presentationTimeStamp,
            makeCopy(sampleBuffer:)
        )
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
            detectionJobs.append(
                DetectionJob(videoSourceId: videoSourceId,
                             imageBuffer: videoSourceImageBuffer,
                             detectFaces: faceDetectionVideoSourceIds.contains(videoSourceId),
                             detectText: textDetectionVideoSourceIds.contains(videoSourceId))
            )
        }
        return detectionJobs
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

    private func enqueueVideoPreview(cameraId: UUID, sampleBuffer: CMSampleBuffer) {
        guard let drawable = videoPreviews[cameraId] else {
            return
        }
        sampleBuffer.setAttachmentDisplayImmediately()
        drawable.enqueue(sampleBuffer, isFirstAfterAttach: false)
    }
}

extension VideoUnit: VideoCaptureSessionDelegate {
    func videoCaptureSessionDidOutput(_ device: AVCaptureDevice,
                                      _ cameraId: UUID?,
                                      _ sampleBuffer: CMSampleBuffer)
    {
        if videoPreviewEnabled, let cameraId {
            enqueueVideoPreview(cameraId: cameraId, sampleBuffer: sampleBuffer)
        }
        if cameraId == sceneVideoSourceId {
            var sampleBuffer = sampleBuffer
            if let bufferedVideo = appendBufferedBuiltinVideo(sampleBuffer, device) {
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
            _ = appendBufferedBuiltinVideo(sampleBuffer, device)
        }
    }

    func videoCaptureSessionWasInterrupted() {
        processorPipelineQueue.async {
            self.prepareFirstFrame()
        }
    }
}

func createBlackImage(width: Double, height: Double) -> CIImage {
    CIImage.black.cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
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
