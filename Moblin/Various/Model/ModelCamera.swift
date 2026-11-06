@preconcurrency import AVFoundation
import Foundation

typealias CameraId = String

struct Camera: Equatable {
    var id: CameraId
    var name: String
}

enum CameraShowType: Equatable {
    case bias
    case whiteBalance
    case iso
    case exposure
    case focus
}

@MainActor
class CameraShow: ObservableObject {
    @Published var type: CameraShowType?

    func toggle(buttonType: CameraShowType) {
        if type == buttonType {
            type = nil
        } else {
            type = buttonType
        }
    }
}

@MainActor
class VideoSources: ObservableObject {
    @Published var back: [Camera] = []
    @Published var front: [Camera] = []
    @Published var external: [Camera] = []
    @Published var rtmp: [Camera] = []
    @Published var srtla: [Camera] = []
    @Published var srtClient: [Camera] = []
    @Published var rist: [Camera] = []
    @Published var rtsp: [Camera] = []
    @Published var whip: [Camera] = []
    @Published var whep: [Camera] = []
    @Published var mediaPlayer: [Camera] = []

    func all() -> [Camera] {
        var cameras: [Camera] = []
        if hasTripleBackCamera {
            cameras.append(backTripleLowEnergyCamera)
        }
        if hasDualBackCamera {
            cameras.append(backDualLowEnergyCamera)
        }
        if hasWideDualBackCamera {
            cameras.append(backWideDualLowEnergyCamera)
        }
        cameras += back
        cameras += front
        cameras += external
        cameras += rtmp
        cameras += srtla
        cameras += srtClient
        cameras += rist
        cameras += rtsp
        cameras += whip
        cameras += whep
        cameras += mediaPlayer
        cameras.append(Camera(id: screenCaptureCameraId.uuidString, name: screenCaptureCameraName))
        cameras.append(Camera(id: noneCameraId.uuidString, name: noneCameraName))
        return cameras
    }
}

@MainActor
final class CameraControl {
    let cameraId: CameraId
    var zoomX: Float?
    var focusLocked: Bool?
    var lockedFocus: Float?
    var exposureAndIsoLocked: Bool?
    var lockedIso: Float?
    var lockedExposure: Float?
    var whiteBalanceLocked: Bool?
    var lockedWhiteBalance: Float?

    init(cameraId: CameraId) {
        self.cameraId = cameraId
    }
}

@MainActor
final class CameraControls {
    private var controls: [CameraId: CameraControl] = [:]

    func control(cameraId: CameraId) -> CameraControl {
        if let control = controls[cameraId] {
            return control
        }
        let control = CameraControl(cameraId: cameraId)
        controls[cameraId] = control
        return control
    }
}

@MainActor
class CameraState: ObservableObject {
    let show = CameraShow()
    var editingLockedFocus = false
    var focusObservation: NSKeyValueObservation?
    var editingLockedIso = false
    var isoObservation: NSKeyValueObservation?
    var editingLockedExposure = false
    var exposureObservation: NSKeyValueObservation?
    var editingLockedWhiteBalance = false
    var whiteBalanceObservation: NSKeyValueObservation?
    @Published var bias: Float = 0.0
    @Published var lockedFocus: Float = 1.0
    @Published var isFocusLocked = false
    @Published var lockedIso: Float = 1.0
    @Published var lockedExposure: Float = 1.0
    @Published var exposure: CMTime = .zero
    @Published var isExposureAndIsoLocked = false
    @Published var lockedWhiteBalance: Float = 0
    @Published var isWhiteBalanceLocked = false
    @Published var manualFocusPoint: CGPoint?

    func setManualFocusPoint(value: CGPoint?) {
        if value != manualFocusPoint {
            manualFocusPoint = value
        }
    }
}

let noneCameraName = String(localized: "None")
let screenCaptureCameraName = String(localized: "Screen capture")
let noneCameraId = UUID(uuidString: "00000000-feed-b1ac-cafe-000000000000")!
let screenCaptureCameraId = UUID(uuidString: "00000000-cafe-babe-beef-000000000000")!
private let backTripleLowEnergyCameraBaseName = String(localized: "Triple (low power)")
private let backDualLowEnergyCameraBaseName = String(localized: "Dual (low power)")
private let backWideDualLowEnergyCameraBaseName = String(localized: "Wide dual (low power)")
private let backTripleLowEnergyCamera = Camera(
    id: "00000000-feed-b1ac-cafe-100000000000",
    name: String(localized: "Back \(backTripleLowEnergyCameraBaseName)")
)
private let backDualLowEnergyCamera = Camera(
    id: "00000000-feed-b1ac-cafe-200000000000",
    name: String(localized: "Back \(backDualLowEnergyCameraBaseName)")
)
private let backWideDualLowEnergyCamera = Camera(
    id: "00000000-feed-b1ac-cafe-300000000000",
    name: String(localized: "Back \(backWideDualLowEnergyCameraBaseName)")
)

extension Model {
    private func cameraControl(for device: AVCaptureDevice) -> CameraControl {
        cameraControls.control(cameraId: device.uniqueID)
    }

    func setFocusPointOfInterest(focusPoint: CGPoint) {
        guard
            let device = cameraDevice, device.isFocusPointOfInterestSupported
        else {
            logger.info("Tap to focus not supported for this camera")
            makeErrorToast(title: String(localized: "Tap to focus not supported for this camera"))
            return
        }
        var focusPointOfInterest = focusPoint
        if stream.portrait {
            focusPointOfInterest.x = focusPoint.y
            focusPointOfInterest.y = 1 - focusPoint.x
        } else if getOrientation() == .landscapeRight {
            focusPointOfInterest.x = 1 - focusPoint.x
            focusPointOfInterest.y = 1 - focusPoint.y
        }
        do {
            try device.lockForConfiguration()
            device.focusPointOfInterest = focusPointOfInterest
            device.focusMode = .autoFocus
            device.exposurePointOfInterest = focusPointOfInterest
            device.exposureMode = .autoExpose
            device.unlockForConfiguration()
            camera.setManualFocusPoint(value: focusPoint)
            startMotionDetection()
        } catch let error as NSError {
            logger.info("while locking device for focusPointOfInterest: \(error)")
        }
        let control = cameraControl(for: device)
        control.focusLocked = false
        control.lockedFocus = nil
        camera.isFocusLocked = false
    }

    func setAutoFocus() {
        stopMotionDetection()
        guard let device = cameraDevice, device.isFocusPointOfInterestSupported else {
            return
        }
        applyAutoFocus(device: device)
        camera.setManualFocusPoint(value: nil)
        let control = cameraControl(for: device)
        control.focusLocked = false
        camera.isFocusLocked = false
    }

    private func applyAutoFocus(device: AVCaptureDevice) {
        guard device.isFocusPointOfInterestSupported else {
            return
        }
        do {
            try device.lockForConfiguration()
            device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
            device.focusMode = .continuousAutoFocus
            device.exposurePointOfInterest = CGPoint(x: 0.5, y: 0.5)
            device.exposureMode = .continuousAutoExposure
            device.unlockForConfiguration()
        } catch let error as NSError {
            logger.info("while locking device for focusPointOfInterest: \(error)")
        }
    }

    func setManualFocus(lensPosition: Float) {
        guard
            let device = cameraDevice, device.isLockingFocusWithCustomLensPositionSupported
        else {
            makeErrorToast(title: String(localized: "Manual focus not supported for this camera"))
            return
        }
        stopMotionDetection()
        applyManualFocus(device: device, lensPosition: lensPosition)
        camera.setManualFocusPoint(value: nil)
        let control = cameraControl(for: device)
        control.focusLocked = true
        control.lockedFocus = lensPosition
        camera.lockedFocus = lensPosition
        camera.isFocusLocked = true
    }

    private func applyManualFocus(device: AVCaptureDevice, lensPosition: Float) {
        do {
            try device.lockForConfiguration()
            device.setFocusModeLocked(lensPosition: lensPosition)
            device.unlockForConfiguration()
        } catch let error as NSError {
            logger.info("while locking device for manual focus: \(error)")
        }
    }

    func isCameraSupportingManualFocus() -> Bool {
        cameraDevice?.isLockingFocusWithCustomLensPositionSupported ?? false
    }

    func startObservingFocus() {
        guard let device = cameraDevice else {
            return
        }
        camera.lockedFocus = device.lensPosition
        camera.focusObservation = device.observe(\.lensPosition) { [weak self] _, _ in
            guard let self else {
                return
            }
            DispatchQueue.main.async {
                guard !self.camera.editingLockedFocus else {
                    return
                }
                self.cameraControl(for: device).lockedFocus = device.lensPosition
                self.camera.lockedFocus = device.lensPosition
            }
        }
    }

    func stopObservingFocus() {
        camera.focusObservation = nil
    }

    func setAutoExposureAndIso() {
        guard
            let device = cameraDevice, device.isExposureModeSupported(.continuousAutoExposure)
        else {
            makeErrorToast(title: String(localized: "Continuous auto exposure not supported for this camera"))
            return
        }
        do {
            try device.lockForConfiguration()
            device.exposureMode = .continuousAutoExposure
            device.unlockForConfiguration()
        } catch let error as NSError {
            logger.info("while locking device for continuous auto exposure: \(error)")
        }
        cameraControl(for: device).exposureAndIsoLocked = false
        camera.isExposureAndIsoLocked = false
    }

    func isCameraSupportingManualExposureAndIso() -> Bool {
        cameraDevice?.isExposureModeSupported(.custom) ?? false
    }

    private func setManualExposureAndIso(exposureFactor: Float?,
                                         isoFactor: Float?,
                                         device: AVCaptureDevice? = nil,
                                         updateUi: Bool = true)
    {
        guard let device = device ?? cameraDevice, device.isExposureModeSupported(.custom) else {
            if updateUi {
                makeErrorToast(title: String(localized: "Manual exposure not supported for this camera"))
            }
            return
        }
        let control = cameraControl(for: device)
        let iso: Float
        let exposure: CMTime
        if let isoFactor {
            iso = factorToIso(device: device, factor: isoFactor)
            control.lockedIso = isoFactor
        } else {
            iso = AVCaptureDevice.currentISO
            control.lockedIso = factorFromIso(device: device, iso: device.iso)
        }
        if let exposureFactor {
            exposure = factorToExposure(device: device, factor: exposureFactor)
            control.lockedExposure = exposureFactor
            if updateUi {
                camera.exposure = exposure
            }
        } else {
            exposure = AVCaptureDevice.currentExposureDuration
            control.lockedExposure = factorFromExposure(device: device, exposure: device.exposureDuration)
            if updateUi {
                camera.exposure = device.exposureDuration
            }
        }
        control.exposureAndIsoLocked = true
        if updateUi {
            camera.isExposureAndIsoLocked = true
        }
        do {
            try device.lockForConfiguration()
            device.setExposureModeCustom(duration: exposure, iso: iso) { _ in }
            device.unlockForConfiguration()
        } catch let error as NSError {
            logger.info("while locking device for manual exposure: \(error)")
        }
    }

    func setManualIso(factor: Float) {
        setManualExposureAndIso(exposureFactor: nil, isoFactor: factor)
    }

    func startObservingIso() {
        guard let device = cameraDevice else {
            return
        }
        camera.lockedIso = factorFromIso(device: device, iso: device.iso)
        camera.isoObservation = device.observe(\.iso) { [weak self] _, _ in
            guard let self else {
                return
            }
            DispatchQueue.main.async {
                guard !self.camera.editingLockedIso else {
                    return
                }
                let iso = factorFromIso(device: device, iso: device.iso)
                self.cameraControl(for: device).lockedIso = iso
                self.camera.lockedIso = iso
            }
        }
    }

    func stopObservingIso() {
        camera.isoObservation = nil
    }

    func setManualExposure(factor: Float) {
        setManualExposureAndIso(exposureFactor: factor, isoFactor: nil)
    }

    func getExposureFactorStep() -> Float {
        guard let device = cameraDevice else {
            return 0.01
        }
        return exposureFactorStep(device: device)
    }

    func startObservingExposure() {
        guard let device = cameraDevice else {
            return
        }
        camera.lockedExposure = factorFromExposure(device: device, exposure: device.exposureDuration)
        camera.exposure = device.exposureDuration
        camera.exposureObservation = device.observe(\.exposureDuration) { [weak self] _, _ in
            guard let self else {
                return
            }
            DispatchQueue.main.async {
                guard !self.camera.editingLockedExposure else {
                    return
                }
                let exposure = factorFromExposure(device: device, exposure: device.exposureDuration)
                self.cameraControl(for: device).lockedExposure = exposure
                self.camera.lockedExposure = exposure
                self.camera.exposure = device.exposureDuration
            }
        }
    }

    func stopObservingExposure() {
        camera.exposureObservation = nil
    }

    func setAutoWhiteBalance() {
        guard
            let device = cameraDevice, device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance)
        else {
            makeErrorToast(
                title: String(localized: "Continuous auto white balance not supported for this camera")
            )
            return
        }
        do {
            try device.lockForConfiguration()
            device.whiteBalanceMode = .continuousAutoWhiteBalance
            device.unlockForConfiguration()
        } catch let error as NSError {
            logger.info("while locking device for continuous auto white balance: \(error)")
        }
        cameraControl(for: device).whiteBalanceLocked = false
        camera.isWhiteBalanceLocked = false
        updateImageButtonState()
    }

    func setManualWhiteBalance(factor: Float) {
        guard
            let device = cameraDevice, device.isLockingWhiteBalanceWithCustomDeviceGainsSupported
        else {
            makeErrorToast(title: String(localized: "Manual white balance not supported for this camera"))
            return
        }
        applyManualWhiteBalance(device: device, factor: factor)
        let control = cameraControl(for: device)
        control.whiteBalanceLocked = true
        control.lockedWhiteBalance = factor
        camera.isWhiteBalanceLocked = true
    }

    private func applyManualWhiteBalance(device: AVCaptureDevice, factor: Float) {
        guard device.isLockingWhiteBalanceWithCustomDeviceGainsSupported else {
            return
        }
        do {
            try device.lockForConfiguration()
            device.setWhiteBalanceModeLocked(with: factorToWhiteBalance(device: device, factor: factor))
            device.unlockForConfiguration()
        } catch let error as NSError {
            logger.info("while locking device for manual white balance: \(error)")
        }
    }

    func restoreCameraControls(device: AVCaptureDevice) {
        let control = cameraControl(for: device)
        let isMainCamera = cameraDevice?.uniqueID == device.uniqueID

        if isMainCamera {
            camera.lockedFocus = control.lockedFocus ?? device.lensPosition
            camera.isFocusLocked = control.focusLocked ?? false
        }
        if let focusLocked = control.focusLocked {
            if focusLocked, let lockedFocus = control.lockedFocus {
                applyManualFocus(device: device, lensPosition: lockedFocus)
            } else if !focusLocked {
                if isMainCamera {
                    stopMotionDetection()
                    camera.setManualFocusPoint(value: nil)
                }
                applyAutoFocus(device: device)
            }
        } else if isMainCamera {
            stopMotionDetection()
            camera.setManualFocusPoint(value: nil)
            applyAutoFocus(device: device)
        }
        if isMainCamera, camera.focusObservation != nil {
            stopObservingFocus()
            startObservingFocus()
        }

        let lockedIso = control.lockedIso ?? factorFromIso(device: device, iso: device.iso)
        let lockedExposure = control.lockedExposure ?? factorFromExposure(
            device: device,
            exposure: device.exposureDuration
        )
        if isMainCamera {
            camera.lockedIso = lockedIso
            camera.lockedExposure = lockedExposure
            camera.exposure = device.exposureDuration
            camera.isExposureAndIsoLocked = control.exposureAndIsoLocked ?? false
        }
        if let exposureAndIsoLocked = control.exposureAndIsoLocked {
            if exposureAndIsoLocked {
                setManualExposureAndIso(
                    exposureFactor: lockedExposure,
                    isoFactor: lockedIso,
                    device: device,
                    updateUi: isMainCamera
                )
            } else if !exposureAndIsoLocked, device.isExposureModeSupported(.continuousAutoExposure) {
                do {
                    try device.lockForConfiguration()
                    device.exposureMode = .continuousAutoExposure
                    device.unlockForConfiguration()
                } catch let error as NSError {
                    logger.info("while locking device for continuous auto exposure: \(error)")
                }
            }
        }
        if isMainCamera {
            if camera.isoObservation != nil {
                stopObservingIso()
                startObservingIso()
            }
            if camera.exposureObservation != nil {
                stopObservingExposure()
                startObservingExposure()
            }
        }

        let lockedWhiteBalance = control.lockedWhiteBalance ?? 0.5
        if isMainCamera {
            camera.lockedWhiteBalance = lockedWhiteBalance
            camera.isWhiteBalanceLocked = control.whiteBalanceLocked ?? false
        }
        if let whiteBalanceLocked = control.whiteBalanceLocked {
            if whiteBalanceLocked, control.lockedWhiteBalance != nil || isMainCamera {
                applyManualWhiteBalance(device: device, factor: lockedWhiteBalance)
            } else if !whiteBalanceLocked, device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                do {
                    try device.lockForConfiguration()
                    device.whiteBalanceMode = .continuousAutoWhiteBalance
                    device.unlockForConfiguration()
                } catch let error as NSError {
                    logger.info("while locking device for continuous auto white balance: \(error)")
                }
            }
        }
        if isMainCamera {
            if let x = setCameraZoomX(x: zoom.x) {
                setZoomXWhenInRange(x: x)
            }
            if camera.whiteBalanceObservation != nil {
                stopObservingWhiteBalance()
                startObservingWhiteBalance()
            }
            updateImageButtonState()
        } else if device.position == .back {
            restoreCameraZoom(device: device, x: zoom.backX)
        } else if let zoomX = control.zoomX {
            restoreCameraZoom(device: device, x: zoomX)
        }
    }

    func isCameraSupportingManualWhiteBalance() -> Bool {
        cameraDevice?.isLockingWhiteBalanceWithCustomDeviceGainsSupported ?? false
    }

    func startObservingWhiteBalance() {
        guard let device = cameraDevice else {
            return
        }
        camera.lockedWhiteBalance = factorFromWhiteBalance(
            device: device,
            gains: device.deviceWhiteBalanceGains.clamped(maxGain: device.maxWhiteBalanceGain)
        )
        camera.whiteBalanceObservation = device.observe(\.deviceWhiteBalanceGains) { [weak self] _, _ in
            guard let self else {
                return
            }
            DispatchQueue.main.async {
                guard !self.camera.editingLockedWhiteBalance else {
                    return
                }
                let factor = factorFromWhiteBalance(
                    device: device,
                    gains: device.deviceWhiteBalanceGains.clamped(maxGain: device.maxWhiteBalanceGain)
                )
                self.cameraControl(for: device).lockedWhiteBalance = factor
                self.camera.lockedWhiteBalance = factor
            }
        }
    }

    func stopObservingWhiteBalance() {
        camera.whiteBalanceObservation = nil
    }

    func colorSpaceUpdated() {
        setColorSpace()
        resetSelectedScene(changeScene: false)
    }

    func lutEnabledUpdated() {
        if database.color.lutEnabled, database.color.space.isAppleLog() {
            media.registerEffect(lutEffect)
        } else {
            media.unregisterEffect(lutEffect)
        }
    }

    func lutUpdated() {
        guard let lut = getLogLutById(id: database.color.lut) else {
            media.unregisterEffect(lutEffect)
            return
        }
        lutEffect.setLut(lut: lut.clone(), imageStorage: imageStorage) {
            self.makeErrorToast(title: $0, subTitle: $1)
        }
    }

    func addLutCube(url: URL) {
        let lut = SettingsColorLut(type: .diskCube, name: "My LUT")
        imageStorage.write(id: lut.id, url: url)
        database.color.diskLutsCube.append(lut)
        resetSelectedScene()
    }

    func removeLutCube(offsets: IndexSet) {
        for offset in offsets {
            let lut = database.color.diskLutsCube[offset]
            imageStorage.remove(id: lut.id)
        }
        database.color.diskLutsCube.remove(atOffsets: offsets)
        resetSelectedScene()
    }

    func addLutPng(data: Data) {
        let lut = SettingsColorLut(type: .disk, name: "My LUT")
        imageStorage.write(id: lut.id, data: data)
        database.color.diskLutsPng.append(lut)
        resetSelectedScene()
    }

    func removeLutPng(offsets: IndexSet) {
        for offset in offsets {
            let lut = database.color.diskLutsPng[offset]
            imageStorage.remove(id: lut.id)
        }
        database.color.diskLutsPng.remove(atOffsets: offsets)
        resetSelectedScene()
    }

    func setLutName(lut: SettingsColorLut, name: String) {
        lut.name = name
    }

    func getLogLutById(id: UUID?) -> SettingsColorLut? {
        database.color.allLuts().first { $0.id == id }
    }

    func updateLutsButtonState() {
        var isOn = showingPanel == .luts
        for lut in database.color.allLuts() where lut.enabled {
            isOn = true
        }
        setQuickButton(type: .luts, isOn: isOn)
    }

    func updateShowCameraPreview() -> Bool {
        let show = shouldShowCameraPreview() && !presentingSceneEditor
        if show != self.show.cameraPreview {
            self.show.cameraPreview = show
        }
        return show
    }

    func toggleCameraPreview() {
        if database.alwaysAttachCameraPreview {
            media.setShowCameraPreview(updateShowCameraPreview())
        } else {
            attachCamera()
        }
    }

    func shouldShowCameraPreview() -> Bool {
        if !(getQuickButton(type: .cameraPreview)?.isOn ?? false) {
            return false
        }
        return cameraDevice != nil
    }

    func updateVideoSources() {
        updateDeviceVideoSources()
        updateRtmpVideoSources()
        updateSrtlaVideoSources()
        updateSrtClientVideoSources()
        updateRistVideoSources()
        updateRtspVideoSources()
        updateWhipVideoSources()
        updateWhepVideoSources()
        updateMediaPlayerVideoSources()
    }

    func updateDeviceVideoSources() {
        videoSources.back = listBuiltinCameras(position: .back)
        videoSources.front = listBuiltinCameras(position: .front)
        if isMac() {
            videoSources.external = []
        } else {
            videoSources.external = listExternalCameras()
        }
    }

    private func listBuiltinCameras(position: AVCaptureDevice.Position) -> [Camera] {
        var deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera,
            .builtInDualCamera,
            .builtInDualWideCamera,
            .builtInUltraWideCamera,
            .builtInWideAngleCamera,
            .builtInTelephotoCamera,
        ]
        if #available(iOS 17.0, *) {
            deviceTypes.append(.external)
        }
        let deviceDiscovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: position
        )
        return deviceDiscovery.devices.map { device in
            Camera(id: device.uniqueID, name: device.name())
        }
    }

    private func listExternalCameras() -> [Camera] {
        var deviceTypes: [AVCaptureDevice.DeviceType] = []
        if #available(iOS 17.0, *) {
            deviceTypes.append(.external)
        }
        let deviceDiscovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: .unspecified
        )
        return deviceDiscovery.devices.map { Camera(id: $0.uniqueID, name: $0.name()) }
    }

    private func isBackCamera(cameraId: CameraId) -> Bool {
        videoSources.back.contains(where: { $0.id == cameraId })
    }

    private func isFrontCamera(cameraId: CameraId) -> Bool {
        videoSources.front.contains(where: { $0.id == cameraId })
    }

    private func isBackTripleLowEnergyAutoCamera(cameraId: CameraId) -> Bool {
        cameraId == backTripleLowEnergyCamera.id
    }

    private func isBackDualLowEnergyAutoCamera(cameraId: CameraId) -> Bool {
        cameraId == backDualLowEnergyCamera.id
    }

    private func isBackWideDualLowEnergyAutoCamera(cameraId: CameraId) -> Bool {
        cameraId == backWideDualLowEnergyCamera.id
    }

    func getCameraId(scene: SettingsScene?) -> CameraId {
        getCameraId(settingsCameraId: scene?.toCameraId())
    }

    func getCameraId(videoSourceWidget: SettingsWidgetVideoSource?) -> CameraId {
        getCameraId(settingsCameraId: videoSourceWidget?.toCameraId())
    }

    func getCameraId(vTuberWidget: SettingsWidgetVTuber?) -> CameraId {
        getCameraId(settingsCameraId: vTuberWidget?.toCameraId())
    }

    func getCameraId(pngTuberWidget: SettingsWidgetPngTuber?) -> CameraId {
        getCameraId(settingsCameraId: pngTuberWidget?.toCameraId())
    }

    func cameraIdToSettingsCameraId(cameraId: CameraId) -> SettingsCameraId {
        if let id = getSrtlaStream(idString: cameraId)?.id {
            .srtla(id: id)
        } else if let id = getSrtClientStream(idString: cameraId)?.id {
            .srt(id: id)
        } else if let id = getRtmpStream(idString: cameraId)?.id {
            .rtmp(id: id)
        } else if let id = getRistStream(idString: cameraId)?.id {
            .rist(id: id)
        } else if let id = getRtspStream(idString: cameraId)?.id {
            .rtsp(id: id)
        } else if let id = getWhipStream(idString: cameraId)?.id {
            .whip(id: id)
        } else if let id = getWhepStream(idString: cameraId)?.id {
            .whep(id: id)
        } else if let id = getMediaPlayer(idString: cameraId)?.id {
            .mediaPlayer(id: id)
        } else if isBackCamera(cameraId: cameraId) {
            .back(id: cameraId)
        } else if isFrontCamera(cameraId: cameraId) {
            .front(id: cameraId)
        } else if isScreenCaptureCamera(cameraId: cameraId) {
            .screenCapture
        } else if isBackTripleLowEnergyAutoCamera(cameraId: cameraId) {
            .backTripleLowEnergy
        } else if isBackDualLowEnergyAutoCamera(cameraId: cameraId) {
            .backDualLowEnergy
        } else if isBackWideDualLowEnergyAutoCamera(cameraId: cameraId) {
            .backWideDualLowEnergy
        } else if isNoneCamera(cameraId: cameraId) {
            .none
        } else {
            .external(id: cameraId, name: getExternalCameraName(cameraId: cameraId))
        }
    }

    func cameraIdToSettingsCameraId(cameraId: UUID) -> SettingsCameraId? {
        if let id = getSrtlaStream(id: cameraId)?.id {
            .srtla(id: id)
        } else if let id = getSrtClientStream(id: cameraId)?.id {
            .srt(id: id)
        } else if let id = getRtmpStream(id: cameraId)?.id {
            .rtmp(id: id)
        } else if let id = getRistStream(id: cameraId)?.id {
            .rist(id: id)
        } else if let id = getRtspStream(id: cameraId)?.id {
            .rtsp(id: id)
        } else if let id = getWhipStream(id: cameraId)?.id {
            .whip(id: id)
        } else if let id = getWhepStream(id: cameraId)?.id {
            .whep(id: id)
        } else if let id = getMediaPlayer(id: cameraId)?.id {
            .mediaPlayer(id: id)
        } else if isScreenCaptureCamera(cameraId: cameraId.uuidString) {
            .screenCapture
        } else if isNoneCamera(cameraId: cameraId.uuidString) {
            SettingsCameraId.none
        } else if let deviceUniqueId = getBuiltinDeviceUniqueId(cameraId: cameraId) {
            cameraIdToSettingsCameraId(cameraId: deviceUniqueId)
        } else {
            nil
        }
    }

    func getCameraId(settingsCameraId: SettingsCameraId?) -> CameraId {
        guard let settingsCameraId else {
            return ""
        }
        switch settingsCameraId {
        case let .rtmp(id):
            return id.uuidString
        case let .srtla(id):
            return id.uuidString
        case let .srt(id):
            return id.uuidString
        case let .rist(id: id):
            return id.uuidString
        case let .rtsp(id: id):
            return id.uuidString
        case let .whip(id: id):
            return id.uuidString
        case let .whep(id: id):
            return id.uuidString
        case let .mediaPlayer(id):
            return id.uuidString
        case let .external(id, _):
            return id
        case let .back(id):
            return id
        case let .front(id):
            return id
        case .screenCapture:
            return screenCaptureCameraId.uuidString
        case .backTripleLowEnergy:
            return backTripleLowEnergyCamera.id
        case .backDualLowEnergy:
            return backDualLowEnergyCamera.id
        case .backWideDualLowEnergy:
            return backWideDualLowEnergyCamera.id
        case .none:
            return noneCameraId.uuidString
        }
    }

    func getCameraPositionName(scene: SettingsScene?) -> String {
        getCameraPositionName(settingsCameraId: scene?.toCameraId())
    }

    func getCameraPositionName(videoSourceWidget: SettingsWidgetVideoSource?) -> String {
        getCameraPositionName(settingsCameraId: videoSourceWidget?.toCameraId())
    }

    func getCameraPositionName(vTuberWidget: SettingsWidgetVTuber?) -> String {
        getCameraPositionName(settingsCameraId: vTuberWidget?.toCameraId())
    }

    func getCameraPositionName(pngTuberWidget: SettingsWidgetPngTuber?) -> String {
        getCameraPositionName(settingsCameraId: pngTuberWidget?.toCameraId())
    }

    private func getCameraPositionName(settingsCameraId: SettingsCameraId?) -> String {
        guard let settingsCameraId else {
            return unknownSad
        }
        switch settingsCameraId {
        case let .rtmp(id):
            return getRtmpStream(id: id)?.camera() ?? unknownSad
        case let .srtla(id):
            return getSrtlaStream(id: id)?.camera() ?? unknownSad
        case let .srt(id):
            return getSrtClientStream(id: id)?.camera() ?? unknownSad
        case let .rist(id):
            return getRistStream(id: id)?.camera() ?? unknownSad
        case let .rtsp(id):
            return getRtspStream(id: id)?.camera() ?? unknownSad
        case let .whip(id):
            return getWhipStream(id: id)?.camera() ?? unknownSad
        case let .whep(id):
            return getWhepStream(id: id)?.camera() ?? unknownSad
        case let .mediaPlayer(id):
            return getMediaPlayer(id: id)?.camera() ?? unknownSad
        case let .external(_, name):
            if !name.isEmpty {
                return name
            } else {
                return unknownSad
            }
        case let .back(id):
            if let camera = videoSources.back.first(where: { $0.id == id }) {
                return camera.name
            } else {
                return unknownSad
            }
        case let .front(id):
            if let camera = videoSources.front.first(where: { $0.id == id }) {
                return camera.name
            } else {
                return unknownSad
            }
        case .screenCapture:
            return screenCaptureCameraName
        case .backTripleLowEnergy:
            return backTripleLowEnergyCamera.name
        case .backDualLowEnergy:
            return backDualLowEnergyCamera.name
        case .backWideDualLowEnergy:
            return backWideDualLowEnergyCamera.name
        case .none:
            return noneCameraName
        }
    }

    func getExternalCameraName(cameraId: CameraId) -> String {
        if let camera = videoSources.external.first(where: { $0.id == cameraId }) {
            camera.name
        } else {
            unknownSad
        }
    }

    func isExternalCameraConnected(cameraId: String) -> Bool {
        videoSources.external.first { $0.id == cameraId } != nil
    }

    func setColorSpace() {
        let colorSpace: AVCaptureColorSpace = switch database.color.space {
        case .srgb:
            .sRGB
        case .p3D65:
            .P3_D65
        case .hlgBt2020:
            .HLG_BT2020
        case .appleLog:
            if #available(iOS 17.0, *) {
                .appleLog
            } else {
                .sRGB
            }
        case .appleLog2:
            if #available(iOS 26.0, *) {
                .appleLog2
            } else {
                .sRGB
            }
        }
        media.setColorSpace(colorSpace: colorSpace) {
            if let x = self.setCameraZoomX(x: self.zoom.x) {
                self.setZoomXWhenInRange(x: x)
            }
            self.lutEnabledUpdated()
        }
    }

    private func getBuiltinCameraId(deviceUniqueId: String) -> UUID {
        if let id = builtinCameraIds[deviceUniqueId] {
            return id
        }
        let cameraId = UUID()
        builtinCameraIds[deviceUniqueId] = cameraId
        return cameraId
    }

    private func getBuiltinDeviceUniqueId(cameraId: UUID) -> String? {
        builtinCameraIds.first { _, value in
            value == cameraId
        }?.key
    }

    func makeCaptureDevice(device: AVCaptureDevice) -> CaptureDevice {
        CaptureDevice(device: device,
                      id: getBuiltinCameraId(deviceUniqueId: device.uniqueID),
                      isVideoMirrored: getVideoMirroredOnStream(device: device))
    }

    private func statusCameraText() -> String {
        getCameraPositionName(scene: findEnabledScene(id: sceneSelector.selectedSceneId))
    }

    func updateStatusCameraText() {
        let status = statusCameraText()
        if status != statusTopLeft.statusCameraText {
            statusTopLeft.statusCameraText = status
        }
    }

    func getVideoSourceId(cameraId: SettingsCameraId) -> UUID? {
        switch cameraId {
        case let .rtmp(id: id):
            id
        case let .srtla(id: id):
            id
        case let .srt(id: id):
            id
        case let .rist(id: id):
            id
        case let .rtsp(id: id):
            id
        case let .whip(id: id):
            id
        case let .whep(id: id):
            id
        case let .mediaPlayer(id: id):
            id
        case .screenCapture:
            screenCaptureCameraId
        case let .back(id: id):
            getBuiltinCameraId(deviceUniqueId: id)
        case let .front(id: id):
            getBuiltinCameraId(deviceUniqueId: id)
        case let .external(id: id, name: _):
            getBuiltinCameraId(deviceUniqueId: id)
        case .backDualLowEnergy:
            getBackLowEnergyCamera(cameraPosition: .backDualLowEnergy)
                .flatMap { getBuiltinCameraId(deviceUniqueId: $0.device.uniqueID) }
        case .backTripleLowEnergy:
            getBackLowEnergyCamera(cameraPosition: .backTripleLowEnergy)
                .flatMap { getBuiltinCameraId(deviceUniqueId: $0.device.uniqueID) }
        case .backWideDualLowEnergy:
            getBackLowEnergyCamera(cameraPosition: .backWideDualLowEnergy)
                .flatMap { getBuiltinCameraId(deviceUniqueId: $0.device.uniqueID) }
        case .none:
            noneCameraId
        }
    }

    func setExposureBias(bias: Float) {
        guard let device = cameraDevice else {
            return
        }
        if bias < device.minExposureTargetBias {
            return
        }
        if bias > device.maxExposureTargetBias {
            return
        }
        do {
            try device.lockForConfiguration()
            device.setExposureTargetBias(bias)
            device.unlockForConfiguration()
        } catch {}
    }
}
