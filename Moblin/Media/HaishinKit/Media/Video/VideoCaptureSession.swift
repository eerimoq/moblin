import AVFoundation
import Photos

struct CaptureDevice {
    let device: AVCaptureDevice
    let id: UUID
    let isVideoMirrored: Bool
}

struct CaptureDevices {
    var hasSceneDevice: Bool
    var devices: [CaptureDevice]
}

protocol VideoCaptureSessionDelegate: AnyObject {
    func videoCaptureSessionDidOutput(_ device: AVCaptureDevice,
                                      _ cameraId: UUID?,
                                      _ sampleBuffer: CMSampleBuffer)
    func videoCaptureSessionWasInterrupted()
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

final class VideoCaptureSession: NSObject, @unchecked Sendable {
    weak var delegate: (any VideoCaptureSessionDelegate)?
    weak var processor: Processor?
    let session = makeCaptureSession()
    private var device: AVCaptureDevice?
    private var captureSessionDevices: [CaptureSessionDevice] = []
    private var isRunning = false
    private var cameraControlsEnabled = false
    private var captureSize = CGSize(width: 1920, height: 1080)
    private var fps = VideoUnit.defaultFrameRate
    private var preferAutoFps = false
    private var colorSpace: AVCaptureColorSpace = .sRGB
    private var isLandscapeStreamAndPortraitUi = false

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
        for device in captureSessionDevices {
            device.output.setSampleBufferDelegate(nil, queue: processorPipelineQueue)
        }
    }

    func attach(params: VideoUnitAttachParams) throws {
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

    func takePhoto() {
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
        attachCameraPreviewLayers(params: params)
    }

    private func attachCameraPreviewLayers(params: VideoUnitAttachParams) {
        for (id, previewLayer) in params.cameraPreviewLayers {
            guard params.attachCameraPreview,
                  let device = captureSessionDevices.first(where: { $0.device.id == id }),
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
        for device in captureSessionDevices {
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

extension VideoCaptureSession: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let input = connection.inputPorts.first?.input as? AVCaptureDeviceInput else {
            return
        }
        let cameraId = captureSessionDevices.first(where: { $0.device.device == input.device })?.device.id
        delegate?.videoCaptureSessionDidOutput(input.device, cameraId, sampleBuffer)
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
