import AVKit
import CoreMotion

extension AVCaptureDevice {
    func getZoomFactorScale(hasUltraWideCamera: Bool) -> Float {
        if hasUltraWideCamera {
            switch deviceType {
            case .builtInTripleCamera, .builtInDualWideCamera, .builtInUltraWideCamera:
                return 0.5
            case .builtInTelephotoCamera:
                return (virtualDeviceSwitchOverVideoZoomFactors.last?.floatValue ?? 10.0) / 2
            default:
                return 1.0
            }
        } else {
            switch deviceType {
            case .builtInTelephotoCamera:
                return virtualDeviceSwitchOverVideoZoomFactors.last?.floatValue ?? 2.0
            default:
                return 1.0
            }
        }
    }

    func getUIZoomRange(hasUltraWideCamera: Bool) -> (Float, Float) {
        let factor = getZoomFactorScale(hasUltraWideCamera: hasUltraWideCamera)
        return (Float(minAvailableVideoZoomFactor) * factor, Float(maxAvailableVideoZoomFactor) * factor)
    }

    var fps: (Double, Double) {
        (1 / activeVideoMinFrameDuration.seconds, 1 / activeVideoMaxFrameDuration.seconds)
    }

    func setFps(frameRate: Float64) {
        if #available(iOS 18, *), activeFormat.isAutoVideoFrameRateSupported {
            isAutoVideoFrameRateEnabled = false
        }
        activeVideoMinFrameDuration = CMTime(value: 100, timescale: CMTimeScale(100 * frameRate))
        activeVideoMaxFrameDuration = CMTime(value: 100, timescale: CMTimeScale(100 * frameRate))
    }

    func setAutoFps() {
        activeVideoMinFrameDuration = .invalid
        activeVideoMaxFrameDuration = .invalid
        if #available(iOS 18, *) {
            isAutoVideoFrameRateEnabled = true
        }
    }
}

func cameraName(device: AVCaptureDevice?) -> String {
    guard let device else {
        return ""
    }
    if isMac() {
        return device.localizedName
    } else {
        switch device.deviceType {
        case .builtInTripleCamera:
            return String(localized: "Triple (auto)")
        case .builtInDualCamera:
            return String(localized: "Dual (auto)")
        case .builtInDualWideCamera:
            return String(localized: "Wide dual (auto)")
        case .builtInUltraWideCamera:
            return String(localized: "Ultra wide")
        case .builtInWideAngleCamera:
            return String(localized: "Wide")
        case .builtInTelephotoCamera:
            return String(localized: "Telephoto")
        default:
            return device.localizedName
        }
    }
}

let hasUltraWideBackCamera = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back) != nil
let hasTripleBackCamera = AVCaptureDevice.default(.builtInTripleCamera, for: .video, position: .back) != nil
let hasDualBackCamera = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) != nil
let hasWideDualBackCamera = AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back) != nil
let hasUltraWideFrontCamera = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .front) != nil

func hasUltraWideCamera(position: AVCaptureDevice.Position) -> Bool {
    switch position {
    case .back:
        return hasUltraWideBackCamera
    case .front:
        return hasUltraWideFrontCamera
    default:
        return false
    }
}

private func getBestBackCameraDevice() -> AVCaptureDevice? {
    var device = AVCaptureDevice.default(.builtInTripleCamera, for: .video, position: .back)
    if device == nil {
        device = AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back)
    }
    if device == nil {
        device = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back)
    }
    if device == nil {
        device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    }
    return device
}

let bestBackCameraDevice = getBestBackCameraDevice()

private func getBestFrontCameraDevice() -> AVCaptureDevice? {
    var device = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .front)
    if device == nil {
        device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
    }
    return device
}

let bestFrontCameraDevice = getBestFrontCameraDevice()

private func getBestBackCameraId() -> String {
    return bestBackCameraDevice?.uniqueID ?? ""
}

let bestBackCameraId = getBestBackCameraId()

private func getDefaultBackCameraPosition() -> SettingsSceneCameraPosition {
    if hasTripleBackCamera {
        return .backTripleLowEnergy
    } else if hasWideDualBackCamera {
        return .backWideDualLowEnergy
    } else if hasDualBackCamera {
        return .backDualLowEnergy
    } else {
        return .back
    }
}

let defaultBackCameraPosition = getDefaultBackCameraPosition()

private func getBestFrontCameraId() -> String {
    return bestFrontCameraDevice?.uniqueID ?? ""
}

let bestFrontCameraId = getBestFrontCameraId()

func hasAppleLog() -> Bool {
    if #available(iOS 17.0, *) {
        for format in bestBackCameraDevice?.formats ?? []
            where format.supportedColorSpaces.contains(.appleLog)
        {
            return true
        }
    }
    return false
}

func factorToIso(device: AVCaptureDevice, factor: Float) -> Float {
    let minIso = device.activeFormat.minISO
    let maxIso = device.activeFormat.maxISO
    var iso = minIso + (maxIso - minIso) * factor.clamped(to: 0 ... 1)
    if !iso.isFinite {
        iso = 0
    }
    return iso
}

func factorFromIso(device: AVCaptureDevice, iso: Float) -> Float {
    let minIso = device.activeFormat.minISO
    let maxIso = device.activeFormat.maxISO
    var factor = (iso - minIso) / (maxIso - minIso)
    if !factor.isFinite {
        factor = 0
    }
    return factor.clamped(to: 0 ... 1)
}

private let minimumExposure: Double = 0.001
private let maximumExposure: Double = 0.05

func factorToExposure(device: AVCaptureDevice, factor: Float) -> CMTime {
    let minExposureDuration = device.activeFormat.minExposureDuration
    let maxExposureDuration = device.activeFormat.maxExposureDuration
    let minExposure = max(minimumExposure, minExposureDuration.seconds)
    var maxExposure = min(maximumExposure, maxExposureDuration.seconds)
    maxExposure = max(minExposure, maxExposure)
    let exposure = CMTime(seconds: minExposure + (maxExposure - minExposure) * Double(factor))
    return exposure.clamped(to: minExposureDuration ... maxExposureDuration)
}

func factorFromExposure(device: AVCaptureDevice, exposure: CMTime) -> Float {
    let minExposure = max(minimumExposure, device.activeFormat.minExposureDuration.seconds)
    var maxExposure = min(maximumExposure, device.activeFormat.maxExposureDuration.seconds)
    maxExposure = max(minExposure, maxExposure)
    var factor = Float((exposure.seconds - minExposure) / (maxExposure - minExposure))
    if !factor.isFinite {
        factor = 0
    }
    return factor.clamped(to: 0 ... 1)
}

let minimumWhiteBalanceTemperature: Float = 2200
let maximumWhiteBalanceTemperature: Float = 10000

func factorToWhiteBalance(device: AVCaptureDevice, factor: Float) -> AVCaptureDevice.WhiteBalanceGains {
    let temperature = minimumWhiteBalanceTemperature +
        (maximumWhiteBalanceTemperature - minimumWhiteBalanceTemperature) * factor
    let temperatureAndTint = AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(
        temperature: temperature,
        tint: 0
    )
    return device.deviceWhiteBalanceGains(for: temperatureAndTint)
        .clamped(maxGain: device.maxWhiteBalanceGain)
}

func factorFromWhiteBalance(device: AVCaptureDevice, gains: AVCaptureDevice.WhiteBalanceGains) -> Float {
    let temperature = device.temperatureAndTintValues(for: gains).temperature
    return (temperature - minimumWhiteBalanceTemperature) /
        (maximumWhiteBalanceTemperature - minimumWhiteBalanceTemperature)
}

extension AVCaptureDevice.WhiteBalanceGains {
    func clamped(maxGain: Float) -> AVCaptureDevice.WhiteBalanceGains {
        return .init(redGain: redGain.clamped(to: 1 ... maxGain),
                     greenGain: greenGain.clamped(to: 1 ... maxGain),
                     blueGain: blueGain.clamped(to: 1 ... maxGain))
    }
}

func calcCameraAngle(gravity: CMAcceleration, portrait: Bool) -> Double {
    if portrait {
        return -1 * (atan2(gravity.y, gravity.x) + .pi / 2)
    } else if gravity.x > 0 {
        return atan2(-gravity.x, -gravity.y) + .pi / 2
    } else {
        return atan2(gravity.x, gravity.y) + .pi / 2
    }
}
