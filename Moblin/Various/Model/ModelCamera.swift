import AVFoundation
import Foundation

struct Camera: Identifiable, Equatable {
    var id: String
    var name: String
}

class CameraState: ObservableObject {
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

let noneCameraId = UUID(uuidString: "00000000-feed-b1ac-cafe-000000000000")!
let screenCaptureCameraId = UUID(uuidString: "00000000-cafe-babe-beef-000000000000")!
let builtinBackCameraId = UUID(uuidString: "00000000-cafe-dead-beef-000000000000")!
let builtinFrontCameraId = UUID(uuidString: "00000000-cafe-dead-beef-000000000001")!
let externalCameraId = UUID(uuidString: "00000000-cafe-dead-beef-000000000002")!
let noneCamera = "None"
let screenCaptureCamera = "Screen capture"
private let backTripleLowEnergyCamera = "Back Triple (low power)"
private let backDualLowEnergyCamera = "Back Dual (low power)"
private let backWideDualLowEnergyCamera = "Back Wide dual (low power)"

extension Model {
    func setFocusPointOfInterest(focusPoint: CGPoint) {
        guard
            let device = cameraDevice, device.isFocusPointOfInterestSupported
        else {
            logger.warning("Tap to focus not supported for this camera")
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
            logger.error("while locking device for focusPointOfInterest: \(error)")
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
            logger.error("while locking device for focusPointOfInterest: \(error)")
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
            logger.error("while locking device for manual focus: \(error)")
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
        return cameraDevice?.isLockingFocusWithCustomLensPositionSupported ?? false
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
            guard !self.camera.editingLockedFocus else {
                return
            }
            self.camera.lockedFocuses[device] = device.lensPosition
            self.camera.lockedFocus = device.lensPosition
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
            logger.error("while locking device for continuous auto exposure: \(error)")
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
        return cameraDevice?.isExposureModeSupported(.custom) ?? false
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
            camera.lockedExposures[device] = factorFromExposure(device: device, exposure: device.exposureDuration)
        }
        camera.isExposuresAndIsosLocked[device] = true
        camera.isExposureAndIsoLocked = true
        do {
            try device.lockForConfiguration()
            device.setExposureModeCustom(duration: exposure, iso: iso) { _ in }
            device.unlockForConfiguration()
        } catch let error as NSError {
            logger.error("while locking device for manual exposure: \(error)")
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
            guard !self.camera.editingLockedIso else {
                return
            }
            let iso = factorFromIso(device: device, iso: device.iso)
            self.camera.lockedIsos[device] = iso
            self.camera.lockedIso = iso
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
            guard !self.camera.editingLockedExposure else {
                return
            }
            let exposure = factorFromExposure(device: device, exposure: device.exposureDuration)
            self.camera.lockedExposures[device] = exposure
            self.camera.lockedExposure = exposure
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
            logger.error("while locking device for continuous auto white balance: \(error)")
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
            logger.error("while locking device for manual white balance: \(error)")
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
        return cameraDevice?.isLockingWhiteBalanceWithCustomDeviceGainsSupported ?? false
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
            guard !self.camera.editingLockedWhiteBalance else {
                return
            }
            let factor = factorFromWhiteBalance(
                device: device,
                gains: device.deviceWhiteBalanceGains.clamped(maxGain: device.maxWhiteBalanceGain)
            )
            self.camera.lockedWhiteBalances[device] = factor
            self.camera.lockedWhiteBalance = factor
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
            Camera(id: device.uniqueID, name: cameraName(device: device))
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
        return database.color.bundledLuts + database.color.diskLutsCube + database.color.diskLutsPng
    }

    func getLogLutById(id: UUID) -> SettingsColorLut? {
        return allLuts().first { $0.id == id }
    }

    func updateLutsButtonState() {
        var isOn = showingPanel == .luts
        for lut in allLuts() where lut.enabled {
            isOn = true
        }
        setGlobalButtonState(type: .luts, isOn: isOn)
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
        if !(getGlobalButton(type: .cameraPreview)?.isOn ?? false) {
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
        return deviceDiscovery.devices.map { device in
            Camera(id: device.uniqueID, name: cameraName(device: device))
        }
    }

    func listCameraPositions(excludeBuiltin: Bool = false) -> [(String, String)] {
        var cameras: [(String, String)] = []
        if !excludeBuiltin {
            if hasTripleBackCamera {
                cameras.append((backTripleLowEnergyCamera, backTripleLowEnergyCamera))
            }
            if hasDualBackCamera {
                cameras.append((backDualLowEnergyCamera, backDualLowEnergyCamera))
            }
            if hasWideDualBackCamera {
                cameras.append((backWideDualLowEnergyCamera, backWideDualLowEnergyCamera))
            }
            cameras += backCameras.map {
                ($0.id, "Back \($0.name)")
            }
            cameras += frontCameras.map {
                ($0.id, "Front \($0.name)")
            }
            cameras += externalCameras.map {
                ($0.id, $0.name)
            }
        }
        cameras += rtmpCameras().map {
            ($0.0.uuidString, $0.1)
        }
        cameras += srtlaCameras().map {
            ($0.0.uuidString, $0.1)
        }
        cameras += ristCameras().map {
            ($0.0.uuidString, $0.1)
        }
        cameras += rtspCameras().map {
            ($0.0.uuidString, $0.1)
        }
        cameras += playerCameras().map {
            ($0.0.uuidString, $0.1)
        }
        cameras.append((screenCaptureCamera, screenCaptureCamera))
        cameras.append((noneCamera, noneCamera))
        return cameras
    }

    func isBackCamera(cameraId: String) -> Bool {
        return backCameras.contains(where: { $0.id == cameraId })
    }

    func isFrontCamera(cameraId: String) -> Bool {
        return frontCameras.contains(where: { $0.id == cameraId })
    }

    func isBackTripleLowEnergyAutoCamera(cameraId: String) -> Bool {
        return cameraId == backTripleLowEnergyCamera
    }

    func isBackDualLowEnergyAutoCamera(cameraId: String) -> Bool {
        return cameraId == backDualLowEnergyCamera
    }

    func isBackWideDualLowEnergyAutoCamera(cameraId: String) -> Bool {
        return cameraId == backWideDualLowEnergyCamera
    }

    func getCameraPositionId(scene: SettingsScene?) -> String {
        return getCameraPositionId(settingsCameraId: scene?.toCameraId())
    }

    func getCameraPositionId(videoSourceWidget: SettingsWidgetVideoSource?) -> String {
        return getCameraPositionId(settingsCameraId: videoSourceWidget?.toCameraId())
    }

    func getCameraPositionId(vTuberWidget: SettingsWidgetVTuber?) -> String {
        return getCameraPositionId(settingsCameraId: vTuberWidget?.toCameraId())
    }

    func getCameraPositionId(pngTuberWidget: SettingsWidgetPngTuber?) -> String {
        return getCameraPositionId(settingsCameraId: pngTuberWidget?.toCameraId())
    }

    func cameraIdToSettingsCameraId(cameraId: String) -> SettingsCameraId {
        if let id = getSrtlaStream(idString: cameraId)?.id {
            return .srtla(id: id)
        } else if let id = getRtmpStream(idString: cameraId)?.id {
            return .rtmp(id: id)
        } else if let id = getRistStream(idString: cameraId)?.id {
            return .rist(id: id)
        } else if let id = getRtspStream(idString: cameraId)?.id {
            return .rtsp(id: id)
        } else if let id = getMediaPlayer(idString: cameraId)?.id {
            return .mediaPlayer(id: id)
        } else if isBackCamera(cameraId: cameraId) {
            return .back(id: cameraId)
        } else if isFrontCamera(cameraId: cameraId) {
            return .front(id: cameraId)
        } else if isScreenCaptureCamera(cameraId: cameraId) {
            return .screenCapture
        } else if isBackTripleLowEnergyAutoCamera(cameraId: cameraId) {
            return .backTripleLowEnergy
        } else if isBackDualLowEnergyAutoCamera(cameraId: cameraId) {
            return .backDualLowEnergy
        } else if isBackWideDualLowEnergyAutoCamera(cameraId: cameraId) {
            return .backWideDualLowEnergy
        } else if isNoneCamera(cameraId: cameraId) {
            return .none
        } else {
            return .external(id: cameraId, name: getExternalCameraName(cameraId: cameraId))
        }
    }

    private func getCameraPositionId(settingsCameraId: SettingsCameraId?) -> String {
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
        case let .mediaPlayer(id):
            return id.uuidString
        case let .external(id, _):
            return id
        case let .back(id):
            return id
        case let .front(id):
            return id
        case .screenCapture:
            return screenCaptureCamera
        case .backTripleLowEnergy:
            return backTripleLowEnergyCamera
        case .backDualLowEnergy:
            return backDualLowEnergyCamera
        case .backWideDualLowEnergy:
            return backWideDualLowEnergyCamera
        case .none:
            return noneCamera
        }
    }

    func getCameraPositionName(scene: SettingsScene?) -> String {
        return getCameraPositionName(settingsCameraId: scene?.toCameraId())
    }

    func getCameraPositionName(videoSourceWidget: SettingsWidgetVideoSource?) -> String {
        return getCameraPositionName(settingsCameraId: videoSourceWidget?.toCameraId())
    }

    func getCameraPositionName(vTuberWidget: SettingsWidgetVTuber?) -> String {
        return getCameraPositionName(settingsCameraId: vTuberWidget?.toCameraId())
    }

    func getCameraPositionName(pngTuberWidget: SettingsWidgetPngTuber?) -> String {
        return getCameraPositionName(settingsCameraId: pngTuberWidget?.toCameraId())
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
                return "Back \(camera.name)"
            } else {
                return unknownSad
            }
        case let .front(id):
            if let camera = frontCameras.first(where: { $0.id == id }) {
                return "Front \(camera.name)"
            } else {
                return unknownSad
            }
        case .screenCapture:
            return screenCaptureCamera
        case .backTripleLowEnergy:
            return backTripleLowEnergyCamera
        case .backDualLowEnergy:
            return backDualLowEnergyCamera
        case .backWideDualLowEnergy:
            return backWideDualLowEnergyCamera
        case .none:
            return noneCamera
        }
    }

    func getExternalCameraName(cameraId: String) -> String {
        if let camera = externalCameras.first(where: { $0.id == cameraId }) {
            return camera.name
        } else {
            return unknownSad
        }
    }

    func isExternalCameraConnected(id: String) -> Bool {
        externalCameras.first { camera in
            camera.id == id
        } != nil
    }

    func setColorSpace() {
        var colorSpace: AVCaptureColorSpace
        switch database.color.space {
        case .srgb:
            colorSpace = .sRGB
        case .p3D65:
            colorSpace = .P3_D65
        case .hlgBt2020:
            colorSpace = .HLG_BT2020
        case .appleLog:
            if #available(iOS 17.0, *) {
                colorSpace = .appleLog
            } else {
                colorSpace = .sRGB
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

    func getBuiltinCameraId(_ uniqueId: String) -> UUID {
        if let id = builtinCameraIds[uniqueId] {
            return id
        }
        let id = UUID()
        builtinCameraIds[uniqueId] = id
        return id
    }

    func makeCaptureDevice(device: AVCaptureDevice) -> CaptureDevice {
        return CaptureDevice(device: device, id: getBuiltinCameraId(device.uniqueID))
    }

    private func statusCameraText() -> String {
        return getCameraPositionName(scene: findEnabledScene(id: sceneSelector.selectedSceneId))
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
            return id
        case let .srtla(id: id):
            return id
        case let .rist(id: id):
            return id
        case let .rtsp(id: id):
            return id
        case let .mediaPlayer(id: id):
            return id
        case .screenCapture:
            return screenCaptureCameraId
        case let .back(id: id):
            return getBuiltinCameraId(id)
        case let .front(id: id):
            return getBuiltinCameraId(id)
        case let .external(id: id, name: _):
            return getBuiltinCameraId(id)
        case .backDualLowEnergy:
            return nil
        case .backTripleLowEnergy:
            return nil
        case .backWideDualLowEnergy:
            return nil
        case .none:
            return noneCameraId
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
