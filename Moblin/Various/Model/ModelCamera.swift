import AVFoundation
import Foundation

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
        if stream.portrait! {
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
            manualFocusPoint = focusPoint
            startMotionDetection()
        } catch let error as NSError {
            logger.error("while locking device for focusPointOfInterest: \(error)")
        }
        manualFocusesEnabled[device] = false
        manualFocusEnabled = false
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
            manualFocusPoint = nil
        } catch let error as NSError {
            logger.error("while locking device for focusPointOfInterest: \(error)")
        }
        manualFocusesEnabled[device] = false
        manualFocusEnabled = false
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
        manualFocusPoint = nil
        manualFocusesEnabled[device] = true
        manualFocusEnabled = true
        manualFocuses[device] = lensPosition
    }

    func setFocusAfterCameraAttach() {
        guard let device = cameraDevice else {
            return
        }
        manualFocus = manualFocuses[device] ?? device.lensPosition
        manualFocusEnabled = manualFocusesEnabled[device] ?? false
        if !manualFocusEnabled {
            setAutoFocus()
        }
        if focusObservation != nil {
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
        manualFocus = device.lensPosition
        focusObservation = device.observe(\.lensPosition) { [weak self] _, _ in
            guard let self else {
                return
            }
            DispatchQueue.main.async {
                guard !self.editingManualFocus else {
                    return
                }
                self.manualFocuses[device] = device.lensPosition
                self.manualFocus = device.lensPosition
            }
        }
    }

    func stopObservingFocus() {
        focusObservation = nil
    }
}

extension Model {
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
        manualIsosEnabled[device] = false
        manualIsoEnabled = false
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
        manualIsosEnabled[device] = true
        manualIsoEnabled = true
        manualIsos[device] = iso
    }

    func setIsoAfterCameraAttach(device: AVCaptureDevice) {
        manualIso = manualIsos[device] ?? factorFromIso(device: device, iso: device.iso)
        manualIsoEnabled = manualIsosEnabled[device] ?? false
        if manualIsoEnabled {
            setManualIso(factor: manualIso)
        }
        if isoObservation != nil {
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
        manualIso = factorFromIso(device: device, iso: device.iso)
        isoObservation = device.observe(\.iso) { [weak self] _, _ in
            guard let self else {
                return
            }
            DispatchQueue.main.async {
                guard !self.editingManualIso else {
                    return
                }
                let iso = factorFromIso(device: device, iso: device.iso)
                self.manualIsos[device] = iso
                self.manualIso = iso
            }
        }
    }

    func stopObservingIso() {
        isoObservation = nil
    }
}

extension Model {
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
        manualWhiteBalancesEnabled[device] = false
        manualWhiteBalanceEnabled = false
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
        manualWhiteBalancesEnabled[device] = true
        manualWhiteBalanceEnabled = true
        manualWhiteBalances[device] = factor
    }

    func setWhiteBalanceAfterCameraAttach(device: AVCaptureDevice) {
        manualWhiteBalance = manualWhiteBalances[device] ?? 0.5
        manualWhiteBalanceEnabled = manualWhiteBalancesEnabled[device] ?? false
        if manualWhiteBalanceEnabled {
            setManualWhiteBalance(factor: manualWhiteBalance)
        }
        if whiteBalanceObservation != nil {
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
        manualWhiteBalance = factorFromWhiteBalance(
            device: device,
            gains: device.deviceWhiteBalanceGains.clamped(maxGain: device.maxWhiteBalanceGain)
        )
        whiteBalanceObservation = device.observe(\.deviceWhiteBalanceGains) { [weak self] _, _ in
            guard let self else {
                return
            }
            DispatchQueue.main.async {
                guard !self.editingManualWhiteBalance else {
                    return
                }
                let factor = factorFromWhiteBalance(
                    device: device,
                    gains: device.deviceWhiteBalanceGains.clamped(maxGain: device.maxWhiteBalanceGain)
                )
                self.manualWhiteBalances[device] = factor
                self.manualWhiteBalance = factor
            }
        }
    }

    func stopObservingWhiteBalance() {
        whiteBalanceObservation = nil
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
}
