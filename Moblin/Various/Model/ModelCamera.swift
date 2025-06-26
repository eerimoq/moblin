import AVFoundation
import Foundation

struct Camera: Identifiable, Equatable {
    var id: String
    var name: String
}

let screenCaptureCameraId = UUID(uuidString: "00000000-cafe-babe-beef-000000000000")!
let builtinBackCameraId = UUID(uuidString: "00000000-cafe-dead-beef-000000000000")!
let builtinFrontCameraId = UUID(uuidString: "00000000-cafe-dead-beef-000000000001")!
let externalCameraId = UUID(uuidString: "00000000-cafe-dead-beef-000000000002")!
let screenCaptureCamera = "Screen capture"
private let backTripleLowEnergyCamera = "Back Triple (low energy)"
private let backDualLowEnergyCamera = "Back Dual (low energy)"
private let backWideDualLowEnergyCamera = "Back Wide dual (low energy)"

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
        camera.manualFocusesEnabled[device] = false
        camera.manualFocusEnabled = false
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
        camera.manualFocusesEnabled[device] = false
        camera.manualFocusEnabled = false
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
        camera.manualFocusesEnabled[device] = true
        camera.manualFocusEnabled = true
        camera.manualFocuses[device] = lensPosition
    }

    func setFocusAfterCameraAttach() {
        guard let device = cameraDevice else {
            return
        }
        camera.manualFocus = camera.manualFocuses[device] ?? device.lensPosition
        camera.manualFocusEnabled = camera.manualFocusesEnabled[device] ?? false
        if !camera.manualFocusEnabled {
            setAutoFocus()
        }
        if camera.focusObservation != nil {
            stopObservingFocus()
            startObservingFocus()
        }
    }

    func isCameraSupportingManualFocus() -> Bool {
        if let device = cameraDevice, device.isLockingFocusWithCustomLensPositionSupported {
            return true
        } else {
            return false
        }
    }

    func startObservingFocus() {
        guard let device = cameraDevice else {
            return
        }
        camera.manualFocus = device.lensPosition
        camera.focusObservation = device.observe(\.lensPosition) { [weak self] _, _ in
            guard let self else {
                return
            }
            guard !self.camera.editingManualFocus else {
                return
            }
            self.camera.manualFocuses[device] = device.lensPosition
            self.camera.manualFocus = device.lensPosition
        }
    }

    func stopObservingFocus() {
        camera.focusObservation = nil
    }

    func setAutoIso() {
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
        camera.manualIsosEnabled[device] = false
        camera.manualIsoEnabled = false
    }

    func setManualIso(factor: Float) {
        guard
            let device = cameraDevice, device.isExposureModeSupported(.custom)
        else {
            makeErrorToast(title: String(localized: "Manual exposure not supported for this camera"))
            return
        }
        let iso = factorToIso(device: device, factor: factor)
        do {
            try device.lockForConfiguration()
            device.setExposureModeCustom(duration: AVCaptureDevice.currentExposureDuration, iso: iso) { _ in
            }
            device.unlockForConfiguration()
        } catch let error as NSError {
            logger.error("while locking device for manual exposure: \(error)")
        }
        camera.manualIsosEnabled[device] = true
        camera.manualIsoEnabled = true
        camera.manualIsos[device] = iso
    }

    func setIsoAfterCameraAttach(device: AVCaptureDevice) {
        camera.manualIso = camera.manualIsos[device] ?? factorFromIso(device: device, iso: device.iso)
        camera.manualIsoEnabled = camera.manualIsosEnabled[device] ?? false
        if camera.manualIsoEnabled {
            setManualIso(factor: camera.manualIso)
        }
        if camera.isoObservation != nil {
            stopObservingIso()
            startObservingIso()
        }
    }

    func isCameraSupportingManualIso() -> Bool {
        if let device = cameraDevice, device.isExposureModeSupported(.custom) {
            return true
        } else {
            return false
        }
    }

    func startObservingIso() {
        guard let device = cameraDevice else {
            return
        }
        camera.manualIso = factorFromIso(device: device, iso: device.iso)
        camera.isoObservation = device.observe(\.iso) { [weak self] _, _ in
            guard let self else {
                return
            }
            guard !self.camera.editingManualIso else {
                return
            }
            let iso = factorFromIso(device: device, iso: device.iso)
            self.camera.manualIsos[device] = iso
            self.camera.manualIso = iso
        }
    }

    func stopObservingIso() {
        camera.isoObservation = nil
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
        camera.manualWhiteBalancesEnabled[device] = false
        camera.manualWhiteBalanceEnabled = false
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
        camera.manualWhiteBalancesEnabled[device] = true
        camera.manualWhiteBalanceEnabled = true
        camera.manualWhiteBalances[device] = factor
    }

    func setWhiteBalanceAfterCameraAttach(device: AVCaptureDevice) {
        camera.manualWhiteBalance = camera.manualWhiteBalances[device] ?? 0.5
        camera.manualWhiteBalanceEnabled = camera.manualWhiteBalancesEnabled[device] ?? false
        if camera.manualWhiteBalanceEnabled {
            setManualWhiteBalance(factor: camera.manualWhiteBalance)
        }
        if camera.whiteBalanceObservation != nil {
            stopObservingWhiteBalance()
            startObservingWhiteBalance()
        }
    }

    func isCameraSupportingManualWhiteBalance() -> Bool {
        if let device = cameraDevice, device.isLockingWhiteBalanceWithCustomDeviceGainsSupported {
            return true
        } else {
            return false
        }
    }

    func startObservingWhiteBalance() {
        guard let device = cameraDevice else {
            return
        }
        camera.manualWhiteBalance = factorFromWhiteBalance(
            device: device,
            gains: device.deviceWhiteBalanceGains.clamped(maxGain: device.maxWhiteBalanceGain)
        )
        camera.whiteBalanceObservation = device.observe(\.deviceWhiteBalanceGains) { [weak self] _, _ in
            guard let self else {
                return
            }
            guard !self.camera.editingManualWhiteBalance else {
                return
            }
            let factor = factorFromWhiteBalance(
                device: device,
                gains: device.deviceWhiteBalanceGains.clamped(maxGain: device.maxWhiteBalanceGain)
            )
            self.camera.manualWhiteBalances[device] = factor
            self.camera.manualWhiteBalance = factor
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
        reloadStreamIfEnabled(stream: stream)
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
        database.color.diskLutsCube!.append(lut)
        resetSelectedScene()
    }

    func removeLutCube(offsets: IndexSet) {
        for offset in offsets {
            let lut = database.color.diskLutsCube![offset]
            imageStorage.remove(id: lut.id)
        }
        database.color.diskLutsCube!.remove(atOffsets: offsets)
        resetSelectedScene()
    }

    func addLutPng(data: Data) {
        let lut = SettingsColorLut(type: .disk, name: "My LUT")
        imageStorage.write(id: lut.id, data: data)
        database.color.diskLutsPng!.append(lut)
        resetSelectedScene()
    }

    func removeLutPng(offsets: IndexSet) {
        for offset in offsets {
            let lut = database.color.diskLutsPng![offset]
            imageStorage.remove(id: lut.id)
        }
        database.color.diskLutsPng!.remove(atOffsets: offsets)
        resetSelectedScene()
    }

    func setLutName(lut: SettingsColorLut, name: String) {
        lut.name = name
    }

    func allLuts() -> [SettingsColorLut] {
        return database.color.bundledLuts + database.color.diskLutsCube! + database.color.diskLutsPng!
    }

    func getLogLutById(id: UUID) -> SettingsColorLut? {
        return allLuts().first { $0.id == id }
    }

    func updateLutsButtonState() {
        var isOn = showingPanel == .luts
        for lut in allLuts() where lut.enabled! {
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
            if hasTripleBackCamera() {
                cameras.append((backTripleLowEnergyCamera, backTripleLowEnergyCamera))
            }
            if hasDualBackCamera() {
                cameras.append((backDualLowEnergyCamera, backDualLowEnergyCamera))
            }
            if hasWideDualBackCamera() {
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
            ($0, $0)
        }
        cameras += srtlaCameras().map {
            ($0, $0)
        }
        cameras += playerCameras().map {
            ($0, $0)
        }
        cameras.append((screenCaptureCamera, screenCaptureCamera))
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
        if isSrtlaCameraOrMic(camera: cameraId) {
            return .srtla(id: getSrtlaStream(camera: cameraId)?.id ?? .init())
        } else if isRtmpCameraOrMic(camera: cameraId) {
            return .rtmp(id: getRtmpStream(camera: cameraId)?.id ?? .init())
        } else if isMediaPlayerCameraOrMic(camera: cameraId) {
            return .mediaPlayer(id: getMediaPlayer(camera: cameraId)?.id ?? .init())
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
            return getRtmpStream(id: id)?.camera() ?? ""
        case let .srtla(id):
            return getSrtlaStream(id: id)?.camera() ?? ""
        case let .mediaPlayer(id):
            return getMediaPlayer(id: id)?.camera() ?? ""
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
        }
    }

    func getExternalCameraName(cameraId: String) -> String {
        if let camera = externalCameras.first(where: { camera in
            camera.id == cameraId
        }) {
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

    func setGlobalToneMapping(on: Bool) {
        guard let cameraDevice else {
            return
        }
        guard cameraDevice.activeFormat.isGlobalToneMappingSupported else {
            logger.info("Global tone mapping is not supported")
            return
        }
        do {
            try cameraDevice.lockForConfiguration()
            cameraDevice.isGlobalToneMappingEnabled = on
            cameraDevice.unlockForConfiguration()
        } catch {
            logger.info("Failed to set global tone mapping")
        }
    }

    func getGlobalToneMappingOn() -> Bool {
        return cameraDevice?.isGlobalToneMappingEnabled ?? false
    }

    private func statusCameraText() -> String {
        return getCameraPositionName(scene: findEnabledScene(id: selectedSceneId))
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
