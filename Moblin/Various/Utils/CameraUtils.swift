@preconcurrency import AVKit
import CoreMotion

extension AVCaptureDevice {
    func getZoomFactorScale(hasUltraWideCamera: Bool) -> Float {
        if hasUltraWideCamera {
            switch deviceType {
            case .builtInTripleCamera, .builtInDualWideCamera, .builtInUltraWideCamera:
                0.5
            case .builtInTelephotoCamera:
                (virtualDeviceSwitchOverVideoZoomFactors.last?.floatValue ?? 10.0) / 2
            default:
                1.0
            }
        } else {
            switch deviceType {
            case .builtInTelephotoCamera:
                virtualDeviceSwitchOverVideoZoomFactors.last?.floatValue ?? 2.0
            default:
                1.0
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

extension AVCaptureDevice {
    func name() -> String {
        if isMac() {
            return localizedName
        } else {
            let name = baseName()
            switch position {
            case .back:
                return String(localized: "Back \(name)")
            case .front:
                return String(localized: "Front \(name)")
            default:
                return name
            }
        }
    }

    private func baseName() -> String {
        switch deviceType {
        case .builtInTripleCamera:
            String(localized: "Triple (auto)")
        case .builtInDualCamera:
            String(localized: "Dual (auto)")
        case .builtInDualWideCamera:
            String(localized: "Wide dual (auto)")
        case .builtInUltraWideCamera:
            String(localized: "Ultra wide")
        case .builtInWideAngleCamera:
            String(localized: "Wide")
        case .builtInTelephotoCamera:
            String(localized: "Telephoto")
        default:
            localizedName
        }
    }
}

let hasUltraWideBackCamera = AVCaptureDevice
    .default(.builtInUltraWideCamera, for: .video, position: .back) != nil
let hasTripleBackCamera = AVCaptureDevice.default(.builtInTripleCamera, for: .video, position: .back) != nil
let hasDualBackCamera = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) != nil
let hasWideDualBackCamera = AVCaptureDevice
    .default(.builtInDualWideCamera, for: .video, position: .back) != nil
let hasUltraWideFrontCamera = AVCaptureDevice
    .default(.builtInUltraWideCamera, for: .video, position: .front) != nil

func hasUltraWideCamera(position: AVCaptureDevice.Position) -> Bool {
    switch position {
    case .back:
        hasUltraWideBackCamera
    case .front:
        hasUltraWideFrontCamera
    default:
        false
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

private func getBestBackCameraId() -> CameraId {
    bestBackCameraDevice?.uniqueID ?? ""
}

let bestBackCameraId = getBestBackCameraId()

private func getDefaultBackCameraPosition() -> SettingsSceneCameraPosition {
    if hasTripleBackCamera {
        .backTripleLowEnergy
    } else if hasWideDualBackCamera {
        .backWideDualLowEnergy
    } else if hasDualBackCamera {
        .backDualLowEnergy
    } else {
        .back
    }
}

let defaultBackCameraPosition = getDefaultBackCameraPosition()

private func getBestFrontCameraId() -> String {
    bestFrontCameraDevice?.uniqueID ?? ""
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

private let shutterSpeeds = [
    8000, 6400, 5000, 4000, 3200, 2500, 2000, 1600, 1250, 1000, 800, 640, 500, 400, 320, 250, 240,
    200, 160, 125, 120, 100, 80, 60, 50, 48, 40, 30, 25, 24, 20, 15, 13, 10, 8,
].map { CMTime(value: 1, timescale: CMTimeScale($0)) }
private let slowestExposureWithoutFrameDuration = CMTime(value: 1, timescale: 20)

func exposures(device: AVCaptureDevice) -> [CMTime] {
    let fastest = device.activeFormat.minExposureDuration
    var slowest = device.activeFormat.maxExposureDuration
    let frameDuration = device.activeVideoMaxFrameDuration
    if frameDuration.isValid, frameDuration.isNumeric, frameDuration.seconds > 0 {
        slowest = min(slowest, frameDuration)
    } else {
        slowest = min(slowest, slowestExposureWithoutFrameDuration)
    }
    slowest = max(fastest, slowest)
    let exposures = shutterSpeeds.filter { $0 >= fastest && $0 <= slowest }
    if exposures.isEmpty {
        return [slowest]
    }
    return exposures
}

func factorToExposure(device: AVCaptureDevice, factor: Float) -> CMTime {
    factorToExposure(exposures: exposures(device: device), factor: factor)
}

func factorToExposure(exposures: [CMTime], factor: Float) -> CMTime {
    guard exposures.count > 1 else {
        return exposures.first ?? CMTime(value: 1, timescale: 60)
    }
    let index = (factor.clamped(to: 0 ... 1) * Float(exposures.count - 1)).rounded()
    return exposures[Int(index)]
}

func factorFromExposure(device: AVCaptureDevice, exposure: CMTime) -> Float {
    factorFromExposure(exposures: exposures(device: device), exposure: exposure)
}

func factorFromExposure(exposures: [CMTime], exposure: CMTime) -> Float {
    guard exposures.count > 1, exposure.seconds > 0 else {
        return 0
    }
    var bestIndex = 0
    var bestDistance = Double.infinity
    for (index, candidate) in exposures.enumerated() {
        let distance = abs(log(candidate.seconds / exposure.seconds))
        if distance < bestDistance {
            bestDistance = distance
            bestIndex = index
        }
    }
    return Float(bestIndex) / Float(exposures.count - 1)
}

func exposureFactorStep(device: AVCaptureDevice) -> Float {
    exposureFactorStep(exposures: exposures(device: device))
}

func exposureFactorStep(exposures: [CMTime]) -> Float {
    guard exposures.count > 1 else {
        return 1
    }
    return 1 / Float(exposures.count - 1)
}

func formatExposure(exposure: CMTime) -> String {
    let seconds = exposure.seconds
    guard seconds > 0, seconds.isFinite else {
        return ""
    }
    return "1/\(Int((1 / seconds).rounded()))"
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
        .init(redGain: redGain.clamped(to: 1 ... maxGain),
              greenGain: greenGain.clamped(to: 1 ... maxGain),
              blueGain: blueGain.clamped(to: 1 ... maxGain))
    }
}

func calcCameraAngle(gravity: CMAcceleration, portrait: Bool) -> Double {
    if portrait {
        -1 * (atan2(gravity.y, gravity.x) + .pi / 2)
    } else if gravity.x > 0 {
        atan2(-gravity.x, -gravity.y) + .pi / 2
    } else {
        atan2(gravity.x, gravity.y) + .pi / 2
    }
}

func useLandscapeStreamAndPortraitUi(_ device: AVCaptureDevice?,
                                     _ isLandscapeStreamAndPortraitUi: Bool) -> Bool
{
    #if !targetEnvironment(macCatalyst)
    if #available(iOS 26, *), isLandscapeStreamAndPortraitUi, device?.dynamicAspectRatio == .ratio9x16 {
        return true
    }
    #endif
    return false
}
