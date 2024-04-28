import AVFoundation
import CoreImage
import UIKit
import Vision

var ioVideoUnitIgnoreFramesAfterAttachSeconds = 0.3
var ioVideoUnitWatchInterval = 1.0
var pixelFormatType = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange

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
        sampleBuffer.isNotSync = replaceSampleBuffer.isNotSync
        return sampleBuffer
    }
}

final class VideoUnit: NSObject {
    let lockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.VideoIOComponent.lock")
    private(set) var device: AVCaptureDevice?
    private var input: AVCaptureInput?
    private var output: AVCaptureVideoDataOutput?
    private var connection: AVCaptureConnection?
    private let context = CIContext()
    weak var drawable: PreviewView?

    var formatDescription: CMVideoFormatDescription? {
        didSet {
            codec.formatDescription = formatDescription
        }
    }

    lazy var codec: VideoCodec = .init(lockQueue: lockQueue)
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
            output?.connections
                .filter { $0.isVideoOrientationSupported }
                .forEach {
                    setOrientation(device: device, connection: $0, orientation: videoOrientation)
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
    private var firstFrame = true

    deinit {
        stopGapFillerTimer()
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
        _ = appendSampleBuffer(sampleBuffer, isFirstAfterAttach: false)
    }

    func attach(_ device: AVCaptureDevice?, _ replaceVideo: UUID?) throws {
        startGapFillerTimer()
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
                lockQueue.sync {
                    firstFrameDate = nil
                    isFirstAfterAttach = true
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
        if let device {
            mixer.mediaSync = .video
            try attachDevice(device, captureSession)
            lockQueue.sync {
                firstFrameDate = nil
                isFirstAfterAttach = true
            }
        } else {
            mixer.mediaSync = .passthrough
            try attachDevice(nil, captureSession)
            stopGapFillerTimer()
        }
        self.device = device
        output?.connections.forEach {
            if $0.isVideoMirroringSupported {
                $0.isVideoMirrored = isVideoMirrored
            }
            if $0.isVideoOrientationSupported {
                setOrientation(device: device, connection: $0, orientation: videoOrientation)
            }
            if $0.isVideoStabilizationSupported {
                $0.preferredVideoStabilizationMode = preferredVideoStabilizationMode
            }
        }
        setDeviceFormat(frameRate: frameRate, colorSpace: colorSpace)
        output?.setSampleBufferDelegate(self, queue: lockQueue)
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

    private func applyEffects(_ imageBuffer: CVImageBuffer,
                              _ sampleBuffer: CMSampleBuffer,
                              _ faceDetections: [VNFaceObservation]?) -> (CVImageBuffer?, CMSampleBuffer?)
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
        guard imageBuffer.width == Int(image.extent.width) && imageBuffer.height == Int(image.extent.height)
        else {
            return (nil, nil)
        }
        guard let pool = getBufferPool(formatDescription: sampleBuffer.formatDescription!) else {
            return (nil, nil)
        }
        var outputImageBuffer: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &outputImageBuffer) == kCVReturnSuccess else {
            return (nil, nil)
        }
        guard let outputImageBuffer else {
            return (nil, nil)
        }
        if let poolColorSpace {
            context.render(image, to: outputImageBuffer, bounds: extent, colorSpace: poolColorSpace)
        } else {
            context.render(image, to: outputImageBuffer)
        }
        guard let formatDescription = CMVideoFormatDescription.create(imageBuffer: outputImageBuffer) else {
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

    func registerEffect(_ effect: VideoEffect) {
        if !effects.contains(effect) {
            effects.append(effect)
        }
    }

    func unregisterEffect(_ effect: VideoEffect) {
        if let index = effects.firstIndex(of: effect) {
            effects.remove(at: index)
        }
    }

    func setPendingAfterAttachEffects(effects: [VideoEffect]) {
        pendingAfterAttachEffects = effects
    }

    func usePendingAfterAttachEffects() {
        if let pendingAfterAttachEffects {
            effects = pendingAfterAttachEffects
            self.pendingAfterAttachEffects = nil
        }
    }

    func setLowFpsImage(enabled: Bool) {
        lowFpsImageEnabled = enabled
        lowFpsImageLatest = 0.0
    }

    func addReplaceVideoSampleBuffer(id: UUID, _ sampleBuffer: CMSampleBuffer) {
        guard let replaceVideo = replaceVideos[id] else {
            return
        }
        replaceVideo.sampleBuffers.append(sampleBuffer)
        replaceVideo.sampleBuffers.sort { sampleBuffer1, sampleBuffer2 in
            sampleBuffer1.presentationTimeStamp < sampleBuffer2.presentationTimeStamp
        }
    }

    func addReplaceVideo(cameraId: UUID, latency: Double) {
        let replaceVideo = ReplaceVideo(latency: latency)
        replaceVideos[cameraId] = replaceVideo
    }

    func removeReplaceVideo(cameraId: UUID) {
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

    private func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer, isFirstAfterAttach: Bool) -> Bool {
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
        if anyEffectNeedsFaceDetections() {
            let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: imageBuffer)
            let faceLandmarksRequest = VNDetectFaceLandmarksRequest { request, error in
                guard error == nil else {
                    self.appendSampleBufferWithFaceDetections(sampleBuffer, isFirstAfterAttach, nil)
                    return
                }
                self.appendSampleBufferWithFaceDetections(sampleBuffer,
                                                          isFirstAfterAttach,
                                                          (request as? VNDetectFaceLandmarksRequest)?.results)
            }
            do {
                try imageRequestHandler.perform([faceLandmarksRequest])
            } catch {
                logger.info("Perform face detection error: \(error)")
                appendSampleBufferWithFaceDetections(sampleBuffer, isFirstAfterAttach, nil)
            }
        } else {
            appendSampleBufferWithFaceDetections(sampleBuffer, isFirstAfterAttach, nil)
        }
        return true
    }

    private func appendSampleBufferWithFaceDetections(
        _ sampleBuffer: CMSampleBuffer,
        _ isFirstAfterAttach: Bool,
        _ faceDetections: [VNFaceObservation]?
    ) {
        guard let imageBuffer = sampleBuffer.imageBuffer else {
            return
        }
        var newImageBuffer: CVImageBuffer?
        var newSampleBuffer: CMSampleBuffer?
        if isFirstAfterAttach, let pendingAfterAttachEffects {
            effects = pendingAfterAttachEffects
            self.pendingAfterAttachEffects = nil
        }
        if !effects.isEmpty {
            (newImageBuffer, newSampleBuffer) = applyEffects(imageBuffer, sampleBuffer, faceDetections)
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
        if lowFpsImageEnabled, let mixer,
           lowFpsImageLatest + ioVideoUnitWatchInterval < modSampleBuffer.presentationTimeStamp.seconds
        {
            lowFpsImageLatest = modSampleBuffer.presentationTimeStamp.seconds
            var ciImage = CIImage(cvPixelBuffer: modImageBuffer)
            let scale = 400.0 / Double(modImageBuffer.width)
            ciImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            let cgImage = context.createCGImage(ciImage, from: ciImage.extent)!
            let image = UIImage(cgImage: cgImage)
            mixer.delegate?.mixerVideo(lowFpsImage: image.jpegData(compressionQuality: 0.3))
        }
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
            output?.connections.filter { $0.isVideoMirroringSupported }.forEach {
                $0.isVideoMirrored = isVideoMirrored
            }
        }
    }

    var preferredVideoStabilizationMode: AVCaptureVideoStabilizationMode = .off {
        didSet {
            output?.connections.filter { $0.isVideoStabilizationSupported }.forEach {
                $0.preferredVideoStabilizationMode = preferredVideoStabilizationMode
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
        if firstFrame {
            firstFrame = false
            logger.info("First video frame: \(sampleBuffer.imageBuffer.debugDescription)")
        }
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
        if appendSampleBuffer(sampleBuffer, isFirstAfterAttach: isFirstAfterAttach) {
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
