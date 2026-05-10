import AVFoundation
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

class CameraState: ObservableObject {
    let show = CameraShow()
    var isFocusesLocked: [AVCaptureDevice: Bool] = [:]
    var lockedFocuses: [AVCaptureDevice: Float] = [:]
    var editingLockedFocus = false
    var focusObservation: NSKeyValueObservation?
    var isExposuresAndIsosLocked: [AVCaptureDevice: Bool] = [:]
    var lockedIsos: [AVCaptureDevice: Float] = [:]
    var editingLockedIso = false
    var isoObservation: NSKeyValueObservation?
    var lockedExposures: [AVCaptureDevice: Float] = [:]
    var editingLockedExposure = false
    var exposureObservation: NSKeyValueObservation?
    var isWhiteBalancesLocked: [AVCaptureDevice: Bool] = [:]
    var lockedWhiteBalances: [AVCaptureDevice: Float] = [:]
    var editingLockedWhiteBalance = false
    var whiteBalanceObservation: NSKeyValueObservation?
    @Published var bias: Float = 0.0
    @Published var lockedFocus: Float = 1.0
    @Published var isFocusLocked = false
    @Published var lockedIso: Float = 1.0
    @Published var lockedExposure: Float = 1.0
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
        camera.isFocusesLocked[device] = false
        camera.isFocusLocked = false
    }

    func setAutoFocus() {
        stopMotionDetection()
        guard let device = cameraDevice, device.isFocusPointOfInterestSupported else {
            return
        }
        do {
            try device.lockForConfiguration()
            device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
            device.focusMode = .continuousAutoFocus
            device.exposurePointOfInterest = CGPoint(x: 0.5, y: 0.5)
            device.exposureMode = .continuousAutoExposure
            device.unlockForConfiguration()
            camera.setManualFocusPoint(value: nil)
        } catch let error as NSError {
            logger.info("while locking device for focusPointOfInterest: \(error)")
        }
        camera.isFocusesLocked[device] = false
        camera.isFocusLocked = false
    }

    func setManualFocus(lensPosition: Float) {
        guard
            let device = cameraDevice, device.isLockingFocusWithCustomLensPositionSupported
        else {
            makeErrorToast(title: String(localized: "Manual focus not supported for this camera"))
            return
        }
        stopMotionDetection()
        do {
            try device.lockForConfiguration()
            device.setFocusModeLocked(lensPosition: lensPosition)
            device.unlockForConfiguration()
        } catch let error as NSError {
            logger.info("while locking device for manual focus: \(error)")
        }
        camera.setManualFocusPoint(value: nil)
        camera.isFocusesLocked[device] = true
        camera.isFocusLocked = true
        camera.lockedFocuses[device] = lensPosition
    }

    func setFocusAfterCameraAttach() {
        guard let device = cameraDevice else {
            return
        }
        camera.lockedFocus = camera.lockedFocuses[device] ?? device.lensPosition
        camera.isFocusLocked = camera.isFocusesLocked[device] ?? false
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
        guard let device = cameraDevice else {
            return
        }
        camera.lockedFocus = device.lensPosition
        camera.focusObservation = device.observe(\.lensPosition) { [weak self] _, _ in
            guard let self else {
                return
            }
            guard !camera.editingLockedFocus else {
                return
            }
            camera.lockedFocuses[device] = device.lensPosition
            camera.lockedFocus = device.lensPosition
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
        camera.isExposuresAndIsosLocked[device] = false
        camera.isExposureAndIsoLocked = false
    }

    func setExposureAndIsoAfterCameraAttach(device: AVCaptureDevice) {
        camera.lockedIso = camera.lockedIsos[device] ?? factorFromIso(device: device, iso: device.iso)
        camera.lockedExposure = camera.lockedExposures[device] ?? factorFromExposure(
            device: device,
            exposure: device.exposureDuration
        )
        camera.isExposureAndIsoLocked = camera.isExposuresAndIsosLocked[device] ?? false
        if camera.isExposureAndIsoLocked {
            setManualExposureAndIso(exposureFactor: camera.lockedExposure, isoFactor: camera.lockedIso)
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

    private func setManualExposureAndIso(exposureFactor: Float?, isoFactor: Float?) {
        guard let device = cameraDevice, device.isExposureModeSupported(.custom) else {
            makeErrorToast(title: String(localized: "Manual exposure not supported for this camera"))
            return
        }
        let iso: Float
        let exposure: CMTime
        if let isoFactor {
            iso = factorToIso(device: device, factor: isoFactor)
            camera.lockedIsos[device] = isoFactor
        } else {
            iso = AVCaptureDevice.currentISO
            camera.lockedIsos[device] = factorFromIso(device: device, iso: device.iso)
        }
        if let exposureFactor {
            exposure = factorToExposure(device: device, factor: exposureFactor)
            camera.lockedExposures[device] = exposureFactor
        } else {
            exposure = AVCaptureDevice.currentExposureDuration
            camera.lockedExposures[device] = factorFromExposure(
                device: device,
                exposure: device.exposureDuration
            )
        }
        camera.isExposuresAndIsosLocked[device] = true
        camera.isExposureAndIsoLocked = true
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
            guard !camera.editingLockedIso else {
                return
            }
            let iso = factorFromIso(device: device, iso: device.iso)
            camera.lockedIsos[device] = iso
            camera.lockedIso = iso
        }
    }

    func stopObservingIso() {
        camera.isoObservation = nil
    }

    func setManualExposure(factor: Float) {
        setManualExposureAndIso(exposureFactor: factor, isoFactor: nil)
    }

    func startObservingExposure() {
        guard let device = cameraDevice else {
            return
        }
        camera.lockedExposure = factorFromExposure(device: device, exposure: device.exposureDuration)
        camera.exposureObservation = device.observe(\.exposureDuration) { [weak self] _, _ in
            guard let self else {
                return
            }
            guard !camera.editingLockedExposure else {
                return
            }
            let exposure = factorFromExposure(device: device, exposure: device.exposureDuration)
            camera.lockedExposures[device] = exposure
            camera.lockedExposure = exposure
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
        camera.isWhiteBalancesLocked[device] = false
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
        do {
            try device.lockForConfiguration()
            device.setWhiteBalanceModeLocked(with: factorToWhiteBalance(device: device, factor: factor))
            device.unlockForConfiguration()
        } catch let error as NSError {
            logger.info("while locking device for manual white balance: \(error)")
        }
        camera.isWhiteBalancesLocked[device] = true
        camera.isWhiteBalanceLocked = true
        camera.lockedWhiteBalances[device] = factor
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
            guard !camera.editingLockedWhiteBalance else {
                return
            }
            let factor = factorFromWhiteBalance(
                device: device,
                gains: device.deviceWhiteBalanceGains.clamped(maxGain: device.maxWhiteBalanceGain)
            )
            camera.lockedWhiteBalances[device] = factor
            camera.lockedWhiteBalance = factor
        }
    }

    func stopObservingWhiteBalance() {
        camera.whiteBalanceObservation = nil
    }

    func listCameras(position: AVCaptureDevice.Position) -> [Camera] {
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
        lutEffect.setLut(lut: lut.clone(), imageStorage: imageStorage) { title, subTitle in
            self.makeErrorToastMain(title: title, subTitle: subTitle)
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

    func allLuts() -> [SettingsColorLut] {
        database.color.bundledLuts + database.color.diskLutsCube + database.color.diskLutsPng
    }

    func getLogLutById(id: UUID) -> SettingsColorLut? {
        allLuts().first { $0.id == id }
    }

    func updateLutsButtonState() {
        var isOn = showingPanel == .luts
        for lut in allLuts() where lut.enabled {
            isOn = true
        }
        setQuickButton(type: .luts, isOn: isOn)
        updateQuickButtonStates()
    }

    func updateShowCameraPreview() -> Bool {
        let show = shouldShowCameraPreview()
        if show != self.show.cameraPreview {
            self.show.cameraPreview = show
        }
        return show
    }

    private func shouldShowCameraPreview() -> Bool {
        if !(getQuickButton(type: .cameraPreview)?.isOn ?? false) {
            return false
        }
        return cameraDevice != nil
    }

    func updateCameraLists() {
        if isMac() {
            externalCameras = []
            backCameras = listCameras(position: .back)
            frontCameras = listCameras(position: .front)
        } else {
            externalCameras = listExternalCameras()
            backCameras = listCameras(position: .back)
            frontCameras = listCameras(position: .front)
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

    func listCameras(excludeBuiltin: Bool = false) -> [Camera] {
        var cameras: [Camera] = []
        if !excludeBuiltin {
            if hasTripleBackCamera {
                cameras.append(backTripleLowEnergyCamera)
            }
            if hasDualBackCamera {
                cameras.append(backDualLowEnergyCamera)
            }
            if hasWideDualBackCamera {
                cameras.append(backWideDualLowEnergyCamera)
            }
            cameras += backCameras
            cameras += frontCameras
            cameras += externalCameras
        }
        cameras += rtmpCameras()
        cameras += srtlaCameras()
        cameras += ristCameras()
        cameras += rtspCameras()
        cameras += whipCameras()
        cameras += whepCameras()
        cameras += playerCameras()
        cameras.append(Camera(id: screenCaptureCameraId.uuidString, name: screenCaptureCameraName))
        cameras.append(Camera(id: noneCameraId.uuidString, name: noneCameraName))
        return cameras
    }

    private func isBackCamera(cameraId: CameraId) -> Bool {
        backCameras.contains(where: { $0.id == cameraId })
    }

    private func isFrontCamera(cameraId: CameraId) -> Bool {
        frontCameras.contains(where: { $0.id == cameraId })
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
            if let camera = backCameras.first(where: { $0.id == id }) {
                return camera.name
            } else {
                return unknownSad
            }
        case let .front(id):
            if let camera = frontCameras.first(where: { $0.id == id }) {
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
        if let camera = externalCameras.first(where: { $0.id == cameraId }) {
            camera.name
        } else {
            unknownSad
        }
    }

    func isExternalCameraConnected(cameraId: String) -> Bool {
        externalCameras.first { $0.id == cameraId } != nil
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
        media.setColorSpace(colorSpace: colorSpace, onComplete: {
            DispatchQueue.main.async {
                if let x = self.setCameraZoomX(x: self.zoom.x) {
                    self.setZoomXWhenInRange(x: x)
                }
                self.lutEnabledUpdated()
            }
        })
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
        guard let position = cameraPosition else {
            return
        }
        guard let device = preferredCamera(position: position) else {
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
