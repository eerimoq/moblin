import AVFoundation
import ImageIO
import Photos

nonisolated(unsafe) var nativeLowLightBoost = false
nonisolated(unsafe) var externalCameraVideoRange = false
nonisolated(unsafe) var photosImageQuality = 0.95

struct CaptureDevice {
    let device: AVCaptureDevice
    let id: UUID
    let isVideoMirrored: Bool
}

struct CaptureDevices {
    var hasSceneDevice: Bool
    var devices: [CaptureDevice]

    func getSceneDevice() -> CaptureDevice? {
        hasSceneDevice ? devices.first : nil
    }
}

protocol VideoCaptureSessionDelegate: AnyObject {
    func videoCaptureSessionDidOutput(_ device: AVCaptureDevice,
                                      _ cameraId: UUID?,
                                      _ sampleBuffer: CMSampleBuffer)
    func videoCaptureSessionWasInterrupted()
}

private func pixelFormatComponentRange(_ pixelFormat: OSType) -> String? {
    guard let description = CVPixelFormatDescriptionCreateWithPixelFormatType(nil,
                                                                              pixelFormat) as? [String: Any]
    else {
        return nil
    }
    return description[kCVPixelFormatComponentRange as String] as? String
}

func isVideoRangePixelFormat(_ pixelFormat: OSType) -> Bool {
    pixelFormatComponentRange(pixelFormat) == kCVPixelFormatComponentRange_VideoRange as String
}

func isFullRangePixelFormat(_ pixelFormat: OSType) -> Bool {
    pixelFormatComponentRange(pixelFormat) == kCVPixelFormatComponentRange_FullRange as String
}

func filterFormatsByColorRange<Format: VideoFormat>(_ formats: [Format],
                                                    _ colorRange: SettingsStreamColorRange) -> [Format]
{
    let preferences: [(Format) -> Bool] = switch colorRange {
    case .full:
        [
            { isFullRangePixelFormat($0.pixelFormat) },
            { $0.pixelFormat != kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange },
        ]
    case .limited:
        [{ isVideoRangePixelFormat($0.pixelFormat) }]
    }
    for isPreferred in preferences {
        let preferredFormats = formats.filter(isPreferred)
        if !preferredFormats.isEmpty {
            return preferredFormats
        }
    }
    return formats
}

protocol VideoFormat {
    var pixelFormat: OSType { get }
}

extension AVCaptureDevice.Format: VideoFormat {
    var pixelFormat: OSType {
        formatDescription.mediaSubType.rawValue
    }
}

#if targetEnvironment(macCatalyst)
final class FormatDescriptionMatcher {
    private var formatDescription: CMVideoFormatDescription?

    func match(_ sampleBuffer: CMSampleBuffer) -> CMSampleBuffer? {
        guard let imageBuffer = sampleBuffer.imageBuffer,
              let formatDescription = sampleBuffer.formatDescription,
              !CMVideoFormatDescriptionMatchesImageBuffer(formatDescription, imageBuffer: imageBuffer)
        else {
            return sampleBuffer
        }
        if self.formatDescription.map({
            !CMVideoFormatDescriptionMatchesImageBuffer($0, imageBuffer: imageBuffer)
        }) ?? true {
            self.formatDescription = CMVideoFormatDescription.create(imageBuffer: imageBuffer)
        }
        guard let formatDescription = self.formatDescription else {
            return nil
        }
        return CMSampleBuffer.create(imageBuffer,
                                     formatDescription,
                                     sampleBuffer.duration,
                                     sampleBuffer.presentationTimeStamp,
                                     sampleBuffer.decodeTimeStamp)
    }
}
#endif

private func isExternalCameraVideoRange(_ device: AVCaptureDevice,
                                        _ colorRange: SettingsStreamColorRange) -> Bool
{
    if #available(iOS 17.0, *) {
        return externalCameraVideoRange && device.deviceType == .external && colorRange == .limited
    }
    return false
}

private final class VideoRangeRelabeler {
    private var pool: CVPixelBufferPool?
    private var poolSize = CGSize.zero
    private var formatDescription: CMVideoFormatDescription?
    private var logged = false

    func relabel(_ sampleBuffer: CMSampleBuffer) -> CMSampleBuffer? {
        guard let imageBuffer = sampleBuffer.imageBuffer,
              CVPixelBufferGetPixelFormatType(imageBuffer) == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        else {
            return sampleBuffer
        }
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        if pool == nil || poolSize != CGSize(width: width, height: height) {
            let attributes: [NSString: AnyObject] = [
                kCVPixelBufferPixelFormatTypeKey: NSNumber(
                    value: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
                ),
                kCVPixelBufferIOSurfacePropertiesKey: NSDictionary(),
                kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue,
                kCVPixelBufferWidthKey: NSNumber(value: width),
                kCVPixelBufferHeightKey: NSNumber(value: height),
            ]
            pool = nil
            CVPixelBufferPoolCreate(nil, nil, attributes as NSDictionary, &pool)
            poolSize = CGSize(width: width, height: height)
            formatDescription = nil
        }
        guard let pool else {
            return nil
        }
        var outputImageBuffer: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &outputImageBuffer) == kCVReturnSuccess,
              let outputImageBuffer
        else {
            return nil
        }
        CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
        CVPixelBufferLockBaseAddress(outputImageBuffer, [])
        for plane in 0 ..< 2 {
            guard let source = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, plane),
                  let destination = CVPixelBufferGetBaseAddressOfPlane(outputImageBuffer, plane)
            else {
                continue
            }
            let sourceStride = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, plane)
            let destinationStride = CVPixelBufferGetBytesPerRowOfPlane(outputImageBuffer, plane)
            let rows = CVPixelBufferGetHeightOfPlane(imageBuffer, plane)
            let bytes = min(sourceStride, destinationStride)
            for row in 0 ..< rows {
                memcpy(destination + row * destinationStride, source + row * sourceStride, bytes)
            }
        }
        CVPixelBufferUnlockBaseAddress(outputImageBuffer, [])
        CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly)
        CVBufferPropagateAttachments(imageBuffer, outputImageBuffer)
        CVBufferSetAttachment(outputImageBuffer,
                              kCVImageBufferYCbCrMatrixKey,
                              kCVImageBufferYCbCrMatrix_ITU_R_709_2,
                              .shouldPropagate)
        if formatDescription == nil {
            formatDescription = CMVideoFormatDescription.create(imageBuffer: outputImageBuffer)
            if !logged {
                logged = true
                logger.info("video-unit: Relabeled 420f to 420v: \(String(describing: formatDescription))")
            }
        }
        guard let formatDescription else {
            return nil
        }
        return CMSampleBuffer.create(outputImageBuffer,
                                     formatDescription,
                                     sampleBuffer.duration,
                                     sampleBuffer.presentationTimeStamp,
                                     sampleBuffer.decodeTimeStamp)
    }
}

private final class DeviceOutputHandler: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let device: AVCaptureDevice
    private let cameraId: UUID
    private weak var delegate: (any VideoCaptureSessionDelegate)?
    private let relabeler: VideoRangeRelabeler?
    #if targetEnvironment(macCatalyst)
    private let formatDescriptionMatcher = FormatDescriptionMatcher()
    #endif

    init(device: AVCaptureDevice,
         cameraId: UUID,
         delegate: (any VideoCaptureSessionDelegate)?,
         relabelToVideoRange: Bool)
    {
        self.device = device
        self.cameraId = cameraId
        self.delegate = delegate
        relabeler = relabelToVideoRange ? VideoRangeRelabeler() : nil
    }

    func captureOutput(
        _: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from _: AVCaptureConnection
    ) {
        #if targetEnvironment(macCatalyst)
        guard let sampleBuffer = formatDescriptionMatcher.match(sampleBuffer) else {
            return
        }
        #endif
        if let relabeler {
            guard let sampleBuffer = relabeler.relabel(sampleBuffer) else {
                return
            }
            delegate?.videoCaptureSessionDidOutput(device, cameraId, sampleBuffer)
        } else {
            delegate?.videoCaptureSessionDidOutput(device, cameraId, sampleBuffer)
        }
    }
}

private struct CaptureSessionDevice {
    let device: CaptureDevice
    let input: AVCaptureInput
    let output: AVCaptureVideoDataOutput
    let connection: AVCaptureConnection
    let photoOutput: AVCapturePhotoOutput?
    let photoConnection: AVCaptureConnection?
    let outputHandler: DeviceOutputHandler
}

private func makeCaptureSession() -> AVCaptureMultiCamSession {
    let session = AVCaptureMultiCamSession()
    session.automaticallyConfiguresCaptureDeviceForWideColor = false
    #if !targetEnvironment(macCatalyst)
    if session.isMultitaskingCameraAccessSupported {
        session.isMultitaskingCameraAccessEnabled = true
    }
    #endif
    return session
}

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

private enum VideoFormatResult {
    case found(format: AVCaptureDevice.Format, useAutoFrameRate: Bool, useLandscapeInPortrait: Bool)
    case notFound(String)
}

final class VideoCaptureSession: NSObject, @unchecked Sendable {
    weak var delegate: (any VideoCaptureSessionDelegate)?
    weak var processor: Processor?
    let session = makeCaptureSession()
    private var device: AVCaptureDevice?
    private var devices: [CaptureSessionDevice] = []
    private var isRunning = false
    private var cameraControlsEnabled = false
    private var captureSize = CGSize(width: 1920, height: 1080)
    private var fps = VideoUnit.defaultFrameRate
    private var preferAutoFps = false
    private var colorSpace: AVCaptureColorSpace = .sRGB
    private var isLandscapeStreamAndPortraitUi = false
    private let colorRange: SettingsStreamColorRange

    var videoOrientation: AVCaptureVideoOrientation = .portrait {
        didSet {
            guard videoOrientation != oldValue else {
                return
            }
            session.beginConfiguration()
            for device in devices {
                updateOrientation(device: device)
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

    init(colorRange: SettingsStreamColorRange) {
        self.colorRange = colorRange
        super.init()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleSessionRuntimeError),
                                               name: .AVCaptureSessionRuntimeError,
                                               object: session)
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

    func getFps() -> Double {
        fps
    }

    func setFps(fps: Float64, preferAutoFps: Bool) {
        self.fps = fps
        self.preferAutoFps = preferAutoFps
        updateDevicesFormat()
    }

    func setColorSpace(colorSpace: AVCaptureColorSpace) {
        self.colorSpace = colorSpace
        updateDevicesFormat()
    }

    func setCaptureSize(_ captureSize: CGSize) {
        self.captureSize = captureSize
        updateDevicesFormat()
    }

    func setCameraControl(enabled: Bool) {
        cameraControlsEnabled = enabled
        session.beginConfiguration()
        updateCameraControls()
        session.commitConfiguration()
    }

    func stopOutputtingSampleBuffers() {
        for device in devices {
            device.output.setSampleBufferDelegate(nil, queue: processorPipelineQueue)
        }
    }

    func attach(params: VideoUnitAttachParams) throws {
        isLandscapeStreamAndPortraitUi = params.isLandscapeStreamAndPortraitUi
        session.beginConfiguration()
        defer {
            session.commitConfiguration()
        }
        removeDevices(session)
        for device in params.devices.devices {
            setDeviceFormat(
                device: device.device,
                fps: fps,
                preferAutoFrameRate: preferAutoFps,
                colorSpace: colorSpace
            )
            try attachDevice(device, session, params.attachPhotoShoot)
        }
        device = params.devices.getSceneDevice()?.device
        for device in devices {
            if device.connection.isVideoMirroringSupported {
                device.connection.isVideoMirrored = device.device.isVideoMirrored
            }
            if device.connection.isVideoStabilizationSupported {
                device.connection.preferredVideoStabilizationMode = params.preferredVideoStabilizationMode
            }
            updateOrientation(device: device)
            device.output.setSampleBufferDelegate(device.outputHandler, queue: processorPipelineQueue)
        }
        updateCameraControls()
        attachCameraPreviewLayers(params: params)
    }

    func takePhoto(flash: Bool) {
        var started = false
        for device in devices {
            guard let photoOutput = device.photoOutput else {
                continue
            }
            started = true
            var codec = AVVideoCodecType.jpeg
            if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                codec = .hevc
            }
            let settings = AVCapturePhotoSettings(format: [
                AVVideoCodecKey: codec,
                AVVideoCompressionPropertiesKey: [AVVideoQualityKey: photosImageQuality],
            ])
            settings.maxPhotoDimensions = photoOutput.maxPhotoDimensions
            settings.photoQualityPrioritization = .balanced
            if flash, photoOutput.supportedFlashModes.contains(.on) {
                settings.flashMode = .on
            }
            settings.metadata = [
                kCGImagePropertyIPTCDictionary as String: [
                    kCGImagePropertyIPTCKeywords as String: [String(localized: "Moblin photo shoot")],
                ],
            ]
            if #available(iOS 18, *) {
                settings.isShutterSoundSuppressionEnabled = true
            }
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
        if !started {
            processor?.delegate.streamPhotoTaken()
        }
    }

    private func updateOrientation(device: CaptureSessionDevice) {
        updateOrientation(device: device, connection: device.connection)
        if let photoConnection = device.photoConnection {
            updateOrientation(device: device, connection: photoConnection)
        }
    }

    private func updateOrientation(device: CaptureSessionDevice, connection: AVCaptureConnection) {
        guard connection.isVideoOrientationSupported else {
            return
        }
        setOrientation(device: device.device.device,
                       isLandscapeStreamAndPortraitUi: isLandscapeStreamAndPortraitUi,
                       connection: connection,
                       orientation: videoOrientation)
    }

    private func attachCameraPreviewLayers(params: VideoUnitAttachParams) {
        for (previewLayer, deviceId) in params.cameraPreviewLayers {
            guard params.attachCameraPreview,
                  let device = devices.first(where: { $0.device.id == deviceId }),
                  let port = device.input.ports.first(where: { $0.mediaType == .video })
            else {
                if previewLayer.session != nil {
                    previewLayer.session = nil
                }
                continue
            }
            if previewLayer.session !== session {
                previewLayer.setSessionWithNoConnection(session)
            }
            let connection = AVCaptureConnection(inputPort: port, videoPreviewLayer: previewLayer)
            guard session.canAddConnection(connection) else {
                continue
            }
            session.addConnection(connection)
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = device.device.isVideoMirrored
            }
        }
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
        for device in devices {
            setDeviceFormat(
                device: device.device.device,
                fps: fps,
                preferAutoFrameRate: preferAutoFps,
                colorSpace: colorSpace
            )
        }
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
        delegate?.videoCaptureSessionWasInterrupted()
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
    ) -> VideoFormatResult {
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
            return .notFound("No format found matching \(height)p\(Int(fps)), \(colorSpace)")
        }
        formats = formats.filter { !$0.isVideoBinned }
        if formats.isEmpty {
            return .notFound("No unbinned video format found")
        }
        let formatColorRange = isExternalCameraVideoRange(device, colorRange) ? .full : colorRange
        guard let format = filterFormatsByColorRange(formats, formatColorRange).first else {
            return .notFound("Unsupported pixel format")
        }
        return .found(format: format,
                      useAutoFrameRate: useAutoFrameRate,
                      useLandscapeInPortrait: useLandscapeInPortrait)
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
        switch findVideoFormat(
            device: device,
            width: Int32(captureSize.width),
            height: Int32(captureSize.height),
            fps: fps,
            preferAutoFrameRate: preferAutoFrameRate,
            colorSpace: colorSpace
        ) {
        case let .found(format, useAutoFrameRate, useLandscapeInPortrait):
            applyDeviceFormat(device: device,
                              format: format,
                              fps: fps,
                              colorSpace: colorSpace,
                              useAutoFrameRate: useAutoFrameRate,
                              useLandscapeInPortrait: useLandscapeInPortrait)
        case let .notFound(error):
            reportFormatNotFound(device, error)
        }
    }

    private func applyDeviceFormat(device: AVCaptureDevice,
                                   format: AVCaptureDevice.Format,
                                   fps: Float64,
                                   colorSpace: AVCaptureColorSpace,
                                   useAutoFrameRate: Bool,
                                   useLandscapeInPortrait: Bool)
    {
        logger.debug("video-unit: Selected format: \(format)")
        do {
            try device.lockForConfiguration()
            if device.activeFormat != format {
                device.activeFormat = format
            }
            device.activeColorSpace = colorSpace
            device.setLowLightBoost(value: nativeLowLightBoost)
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
                              _ session: AVCaptureMultiCamSession,
                              _ attachPhotoShoot: Bool) throws
    {
        let input = try AVCaptureDeviceInput(device: device.device)
        let output = AVCaptureVideoDataOutput()
        let relabelToVideoRange = isExternalCameraVideoRange(device.device, colorRange)
        // Should be removed? Forces extra conversion of HLG and AppleLog formats?
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: relabelToVideoRange
                ? kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
                : colorRange.pixelFormatType(),
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
        if attachPhotoShoot {
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
            devices.append(CaptureSessionDevice(
                device: device,
                input: input,
                output: output,
                connection: connection!,
                photoOutput: photoOutput,
                photoConnection: photoConnection,
                outputHandler: DeviceOutputHandler(
                    device: device.device,
                    cameraId: device.id,
                    delegate: delegate,
                    relabelToVideoRange: relabelToVideoRange
                )
            ))
        }
    }

    private func removeDevices(_ session: AVCaptureMultiCamSession) {
        for device in devices {
            removeConnection(session, device.photoConnection)
            removeOutput(session, device.photoOutput)
            removeConnection(session, device.connection)
            removeInput(session, device.input)
            removeOutput(session, device.output)
        }
        devices.removeAll()
    }

    private func removeConnection(_ session: AVCaptureMultiCamSession, _ connection: AVCaptureConnection?) {
        if let connection, session.connections.contains(connection) {
            session.removeConnection(connection)
        }
    }

    private func removeInput(_ session: AVCaptureMultiCamSession, _ input: AVCaptureInput?) {
        if let input, session.inputs.contains(input) {
            session.removeInput(input)
        }
    }

    private func removeOutput(_ session: AVCaptureMultiCamSession, _ output: AVCaptureOutput?) {
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
}

@available(iOS 18.0, *)
extension VideoCaptureSession: AVCaptureSessionControlsDelegate {
    func sessionControlsDidBecomeActive(_: AVCaptureSession) {}

    func sessionControlsWillEnterFullscreenAppearance(_: AVCaptureSession) {}

    func sessionControlsWillExitFullscreenAppearance(_: AVCaptureSession) {}

    func sessionControlsDidBecomeInactive(_: AVCaptureSession) {}
}

extension VideoCaptureSession: AVCapturePhotoCaptureDelegate {
    func photoOutput(_: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        processor?.delegate.streamPhotoTaken()
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
