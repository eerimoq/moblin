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
class CameraState: ObservableObject {
    let show = CameraShow()
    var isFocusesLocked: [AVCaptureDevice: Bool] = [:]
    var lockedFocuses: [AVCaptureDevice: Float] = [:]
    var editingLockedFocus = false
    var focusObservation: NSKeyValueObservation?
    var isIsosLocked: [AVCaptureDevice: Bool] = [:]
    var lockedIsos: [AVCaptureDevice: Float] = [:]
    var editingLockedIso = false
    var isoObservation: NSKeyValueObservation?
    var isExposuresLocked: [AVCaptureDevice: Bool] = [:]
    var lockedExposures: [AVCaptureDevice: Float] = [:]
    var editingLockedExposure = false
    var exposureObservation: NSKeyValueObservation?
    var exposureTargetOffsetObservation: NSKeyValueObservation?
    var adjustingUnlockedExposureOrIso = false
    var isWhiteBalancesLocked: [AVCaptureDevice: Bool] = [:]
    var lockedWhiteBalances: [AVCaptureDevice: Float] = [:]
    var editingLockedWhiteBalance = false
    var whiteBalanceObservation: NSKeyValueObservation?
    @Published var bias: Float = 0.0
    @Published var lockedFocus: Float = 1.0
    @Published var isFocusLocked = false
    @Published var lockedIso: Float = 1.0
    @Published var isIsoLocked = false
    @Published var lockedExposure: Float = 1.0
    @Published var exposure: CMTime = .zero
    @Published var isExposureLocked = false
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
    func setFocusPointOfInterest(focusPoint: CGPoint) {
        guard let cameraDevice, cameraDevice.isFocusPointOfInterestSupported else {
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
            try cameraDevice.lockForConfiguration()
            cameraDevice.focusPointOfInterest = focusPointOfInterest
            cameraDevice.focusMode = .autoFocus
            cameraDevice.exposurePointOfInterest = focusPointOfInterest
            if !isExposureOrIsoLocked(device: cameraDevice) {
                cameraDevice.exposureMode = .autoExpose
            }
            cameraDevice.unlockForConfiguration()
            camera.setManualFocusPoint(value: focusPoint)
            startMotionDetection()
        } catch let error as NSError {
            logger.info("while locking device for focusPointOfInterest: \(error)")
        }
        camera.isFocusesLocked[cameraDevice] = false
        camera.isFocusLocked = false
    }

    func setAutoFocus() {
        stopMotionDetection()
        guard let cameraDevice, cameraDevice.isFocusPointOfInterestSupported else {
            return
        }
        do {
            try cameraDevice.lockForConfiguration()
            cameraDevice.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
            cameraDevice.focusMode = .continuousAutoFocus
            cameraDevice.exposurePointOfInterest = CGPoint(x: 0.5, y: 0.5)
            if !isExposureOrIsoLocked(device: cameraDevice) {
                cameraDevice.exposureMode = .continuousAutoExposure
            }
            cameraDevice.unlockForConfiguration()
            camera.setManualFocusPoint(value: nil)
        } catch let error as NSError {
            logger.info("while locking device for focusPointOfInterest: \(error)")
        }
        camera.isFocusesLocked[cameraDevice] = false
        camera.isFocusLocked = false
    }

    func setManualFocus(lensPosition: Float) {
        guard let cameraDevice, cameraDevice.isLockingFocusWithCustomLensPositionSupported else {
            makeErrorToast(title: String(localized: "Manual focus not supported for this camera"))
            return
        }
        stopMotionDetection()
        do {
            try cameraDevice.lockForConfiguration()
            cameraDevice.setFocusModeLocked(lensPosition: lensPosition)
            cameraDevice.unlockForConfiguration()
        } catch let error as NSError {
            logger.info("while locking device for manual focus: \(error)")
        }
        camera.setManualFocusPoint(value: nil)
        camera.isFocusesLocked[cameraDevice] = true
        camera.isFocusLocked = true
        camera.lockedFocuses[cameraDevice] = lensPosition
    }

    func setFocusAfterCameraAttach() {
        guard let cameraDevice else {
            return
        }
        camera.lockedFocus = camera.lockedFocuses[cameraDevice] ?? cameraDevice.lensPosition
        camera.isFocusLocked = camera.isFocusesLocked[cameraDevice] ?? false
        if !camera.isFocusLocked {
            setAutoFocus()
        }
        if camera.focusObservation != nil {
            stopObservingFocus()
            startObservingFocus()
        }
    }

    func isCameraSupportingManualFocus() -> Bool {
        cameraDevice?.isLockingFocusWithCustomLensPositionSupported ?? false
    }

    func startObservingFocus() {
        guard let cameraDevice else {
            return
        }
        camera.lockedFocus = cameraDevice.lensPosition
        camera.focusObservation = cameraDevice.observe(\.lensPosition) { _, _ in
            DispatchQueue.main.async {
                guard !self.camera.editingLockedFocus else {
                    return
                }
                self.camera.lockedFocuses[cameraDevice] = cameraDevice.lensPosition
                self.camera.lockedFocus = cameraDevice.lensPosition
            }
        }
    }

    func stopObservingFocus() {
        camera.focusObservation = nil
    }

    func setAutoIso() {
        guard let cameraDevice else {
            return
        }
        camera.isIsosLocked[cameraDevice] = false
        camera.isIsoLocked = false
        applyExposureAndIso(device: cameraDevice)
    }

    func setManualIso(factor: Float) {
        guard let cameraDevice else {
            return
        }
        camera.lockedIso = factor
        camera.lockedIsos[cameraDevice] = factor
        camera.isIsosLocked[cameraDevice] = true
        camera.isIsoLocked = true
        applyExposureAndIso(device: cameraDevice)
    }

    func setAutoExposure() {
        guard let cameraDevice else {
            return
        }
        camera.isExposuresLocked[cameraDevice] = false
        camera.isExposureLocked = false
        applyExposureAndIso(device: cameraDevice)
    }

    func setManualExposure(factor: Float) {
        guard let cameraDevice else {
            return
        }
        camera.lockedExposure = factor
        camera.lockedExposures[cameraDevice] = factor
        camera.isExposuresLocked[cameraDevice] = true
        camera.isExposureLocked = true
        applyExposureAndIso(device: cameraDevice)
    }

    func setExposureAndIsoAfterCameraAttach(device: AVCaptureDevice) {
        camera.lockedIso = camera.lockedIsos[device] ?? factorFromIso(device: device, iso: device.iso)
        camera.lockedExposure = camera.lockedExposures[device] ?? factorFromExposure(
            device: device,
            exposure: device.exposureDuration
        )
        camera.exposure = device.exposureDuration
        camera.isIsoLocked = camera.isIsosLocked[device] ?? false
        camera.isExposureLocked = camera.isExposuresLocked[device] ?? false
        if isExposureOrIsoLocked() {
            applyExposureAndIso(device: device)
        } else {
            stopAdjustingUnlockedExposureOrIso()
        }
        if camera.isoObservation != nil {
            stopObservingIso()
            startObservingIso()
        }
        if camera.exposureObservation != nil {
            stopObservingExposure()
            startObservingExposure()
        }
    }

    func isCameraSupportingManualExposureAndIso() -> Bool {
        cameraDevice?.isExposureModeSupported(.custom) ?? false
    }

    func isExposureOrIsoLocked() -> Bool {
        camera.isIsoLocked || camera.isExposureLocked
    }

    private func isExposureOrIsoLocked(device: AVCaptureDevice) -> Bool {
        (camera.isIsosLocked[device] ?? false) || (camera.isExposuresLocked[device] ?? false)
    }

    private func applyExposureAndIso(device: AVCaptureDevice) {
        stopAdjustingUnlockedExposureOrIso()
        if isExposureOrIsoLocked() {
            applyCustomExposureAndIso(device: device)
        } else {
            applyContinuousAutoExposure(device: device)
        }
    }

    private func applyContinuousAutoExposure(device: AVCaptureDevice) {
        guard device.isExposureModeSupported(.continuousAutoExposure) else {
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
    }

    private func applyCustomExposureAndIso(device: AVCaptureDevice) {
        guard device.isExposureModeSupported(.custom) else {
            makeErrorToast(title: String(localized: "Manual exposure not supported for this camera"))
            return
        }
        let iso: Float = if camera.isIsoLocked {
            factorToIso(device: device, factor: camera.lockedIso)
        } else {
            AVCaptureDevice.currentISO
        }
        let exposure: CMTime
        if camera.isExposureLocked {
            exposure = factorToExposure(device: device, factor: camera.lockedExposure)
            camera.exposure = exposure
        } else {
            exposure = AVCaptureDevice.currentExposureDuration
            camera.exposure = device.exposureDuration
        }
        setExposureModeCustom(device: device, exposure: exposure, iso: iso)
        if camera.isIsoLocked != camera.isExposureLocked {
            startAdjustingUnlockedExposureOrIso(device: device)
        }
    }

    private func setExposureModeCustom(device: AVCaptureDevice, exposure: CMTime, iso: Float) {
        camera.adjustingUnlockedExposureOrIso = true
        do {
            try device.lockForConfiguration()
            device.setExposureModeCustom(duration: exposure, iso: iso) { _ in
                DispatchQueue.main.async {
                    self.camera.adjustingUnlockedExposureOrIso = false
                }
            }
            device.unlockForConfiguration()
        } catch let error as NSError {
            logger.info("while locking device for manual exposure: \(error)")
            camera.adjustingUnlockedExposureOrIso = false
        }
    }

    private func startAdjustingUnlockedExposureOrIso(device: AVCaptureDevice) {
        camera.exposureTargetOffsetObservation = device
            .observe(\.exposureTargetOffset, options: [.new]) { _, change in
                guard let offset = change.newValue, offset.isFinite, abs(offset) > 0.1 else {
                    return
                }
                DispatchQueue.main.async {
                    self.adjustUnlockedExposureOrIso(device: device)
                }
            }
    }

    private func stopAdjustingUnlockedExposureOrIso() {
        camera.exposureTargetOffsetObservation = nil
        camera.adjustingUnlockedExposureOrIso = false
    }

    private func adjustUnlockedExposureOrIso(device: AVCaptureDevice) {
        guard device == cameraDevice, device.exposureMode == .custom, !camera.adjustingUnlockedExposureOrIso
        else {
            return
        }
        let offset = device.exposureTargetOffset
        guard offset.isFinite, abs(offset) > 0.1 else {
            return
        }
        let factor = pow(2, -offset * 0.5)
        let exposure: CMTime
        let iso: Float
        if camera.isExposureLocked, !camera.isIsoLocked {
            let minIso = device.activeFormat.minISO
            let maxIso = device.activeFormat.maxISO
            iso = (device.iso * factor).clamped(to: minIso ... maxIso)
            guard abs(iso / device.iso - 1) > 0.01 else {
                return
            }
            exposure = factorToExposure(device: device, factor: camera.lockedExposure)
        } else if camera.isIsoLocked, !camera.isExposureLocked {
            let exposures = exposures(device: device)
            exposure = CMTimeMultiplyByFloat64(device.exposureDuration, multiplier: Double(factor))
                .clamped(to: exposures.first! ... exposures.last!)
            guard abs(exposure.seconds / device.exposureDuration.seconds - 1) > 0.01 else {
                return
            }
            iso = factorToIso(device: device, factor: camera.lockedIso)
        } else {
            return
        }
        setExposureModeCustom(device: device, exposure: exposure, iso: iso)
    }

    func startObservingIso() {
        guard let cameraDevice else {
            return
        }
        camera.lockedIso = factorFromIso(device: cameraDevice, iso: cameraDevice.iso)
        camera.isoObservation = cameraDevice.observe(\.iso) { _, _ in
            DispatchQueue.main.async {
                guard !self.camera.editingLockedIso else {
                    return
                }
                let iso = factorFromIso(device: cameraDevice, iso: cameraDevice.iso)
                self.camera.lockedIsos[cameraDevice] = iso
                self.camera.lockedIso = iso
            }
        }
    }

    func stopObservingIso() {
        camera.isoObservation = nil
    }

    func getExposureFactorStep() -> Float {
        guard let cameraDevice else {
            return 0.01
        }
        return exposureFactorStep(device: cameraDevice)
    }

    func startObservingExposure() {
        guard let cameraDevice else {
            return
        }
        camera.lockedExposure = factorFromExposure(
            device: cameraDevice,
            exposure: cameraDevice.exposureDuration
        )
        camera.exposure = cameraDevice.exposureDuration
        camera.exposureObservation = cameraDevice.observe(\.exposureDuration) { _, _ in
            DispatchQueue.main.async {
                guard !self.camera.editingLockedExposure else {
                    return
                }
                let exposure = factorFromExposure(
                    device: cameraDevice,
                    exposure: cameraDevice.exposureDuration
                )
                self.camera.lockedExposures[cameraDevice] = exposure
                self.camera.lockedExposure = exposure
                self.camera.exposure = cameraDevice.exposureDuration
            }
        }
    }

    func stopObservingExposure() {
        camera.exposureObservation = nil
    }

    func setAutoWhiteBalance() {
        guard let cameraDevice, cameraDevice.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) else {
            makeErrorToast(
                title: String(localized: "Continuous auto white balance not supported for this camera")
            )
            return
        }
        do {
            try cameraDevice.lockForConfiguration()
            cameraDevice.whiteBalanceMode = .continuousAutoWhiteBalance
            cameraDevice.unlockForConfiguration()
        } catch let error as NSError {
            logger.info("while locking device for continuous auto white balance: \(error)")
        }
        camera.isWhiteBalancesLocked[cameraDevice] = false
        camera.isWhiteBalanceLocked = false
        updateImageButtonState()
    }

    func setManualWhiteBalance(factor: Float) {
        guard let cameraDevice, cameraDevice.isLockingWhiteBalanceWithCustomDeviceGainsSupported else {
            makeErrorToast(title: String(localized: "Manual white balance not supported for this camera"))
            return
        }
        do {
            try cameraDevice.lockForConfiguration()
            cameraDevice.setWhiteBalanceModeLocked(with: factorToWhiteBalance(
                device: cameraDevice,
                factor: factor
            ))
            cameraDevice.unlockForConfiguration()
        } catch let error as NSError {
            logger.info("while locking device for manual white balance: \(error)")
        }
        camera.isWhiteBalancesLocked[cameraDevice] = true
        camera.isWhiteBalanceLocked = true
        camera.lockedWhiteBalances[cameraDevice] = factor
    }

    func setWhiteBalanceAfterCameraAttach(device: AVCaptureDevice) {
        camera.lockedWhiteBalance = camera.lockedWhiteBalances[device] ?? 0.5
        camera.isWhiteBalanceLocked = camera.isWhiteBalancesLocked[device] ?? false
        if camera.isWhiteBalanceLocked {
            setManualWhiteBalance(factor: camera.lockedWhiteBalance)
        }
        if camera.whiteBalanceObservation != nil {
            stopObservingWhiteBalance()
            startObservingWhiteBalance()
        }
    }

    func isCameraSupportingManualWhiteBalance() -> Bool {
        cameraDevice?.isLockingWhiteBalanceWithCustomDeviceGainsSupported ?? false
    }

    func startObservingWhiteBalance() {
        guard let cameraDevice else {
            return
        }
        camera.lockedWhiteBalance = factorFromWhiteBalance(
            device: cameraDevice,
            gains: cameraDevice.deviceWhiteBalanceGains.clamped(maxGain: cameraDevice.maxWhiteBalanceGain)
        )
        camera.whiteBalanceObservation = cameraDevice.observe(\.deviceWhiteBalanceGains) { _, _ in
            DispatchQueue.main.async {
                guard !self.camera.editingLockedWhiteBalance else {
                    return
                }
                let factor = factorFromWhiteBalance(
                    device: cameraDevice,
                    gains: cameraDevice.deviceWhiteBalanceGains
                        .clamped(maxGain: cameraDevice.maxWhiteBalanceGain)
                )
                self.camera.lockedWhiteBalances[cameraDevice] = factor
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
        if database.color.lutEnabled, database.color.space == .appleLog {
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
        let show = shouldShowCameraPreview()
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

    private func shouldShowCameraPreview() -> Bool {
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

    private func getCameraId(settingsCameraId: SettingsCameraId?) -> CameraId {
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
            nil
        case .backTripleLowEnergy:
            nil
        case .backWideDualLowEnergy:
            nil
        case .none:
            noneCameraId
        }
    }

    func setExposureBias(bias: Float) {
        guard let cameraDevice else {
            return
        }
        if bias < cameraDevice.minExposureTargetBias {
            return
        }
        if bias > cameraDevice.maxExposureTargetBias {
            return
        }
        do {
            try cameraDevice.lockForConfiguration()
            cameraDevice.setExposureTargetBias(bias)
            cameraDevice.unlockForConfiguration()
        } catch {}
    }
}
