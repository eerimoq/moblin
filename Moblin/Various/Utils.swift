import AVKit
import MapKit
import MetalPetal
import SwiftUI
import WeatherKit

extension UIImage {
    func scalePreservingAspectRatio(targetSize: CGSize) -> UIImage {
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        let scaleFactor = min(widthRatio, heightRatio)
        let scaledImageSize = CGSize(
            width: size.width * scaleFactor,
            height: size.height * scaleFactor
        )
        let renderer = UIGraphicsImageRenderer(
            size: scaledImageSize
        )
        let scaledImage = renderer.image { _ in
            self.draw(in: CGRect(
                origin: .zero,
                size: scaledImageSize
            ))
        }
        return scaledImage
    }

    func resize(height: CGFloat) -> UIImage {
        let size = CGSize(width: size.width * (height / size.height), height: height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }

        return image.withRenderingMode(renderingMode)
    }
}

func widgetImage(widget: SettingsWidget) -> String {
    switch widget.type {
    case .image:
        return "photo"
    case .videoEffect:
        return "camera.filters"
    case .browser:
        return "globe"
    case .text:
        return "textformat"
    case .crop:
        return "crop"
    case .map:
        return "map"
    case .scene:
        return "photo.on.rectangle"
    case .qrCode:
        return "qrcode"
    case .alerts:
        return "megaphone"
    case .videoSource:
        return "video"
    case .scoreboard:
        return "rectangle.split.2x1"
    }
}

extension Data {
    static func random(length: Int) -> Data {
        return Data((0 ..< length).map { _ in UInt8.random(in: UInt8.min ... UInt8.max) })
    }
}

func randomString() -> String {
    return Data.random(length: 64).base64EncodedString()
}

func randomHumanString() -> String {
    return Data.random(length: 15).base64EncodedString().replacingOccurrences(
        of: "[+/=]",
        with: "",
        options: .regularExpression
    )
}

func randomName() -> String {
    let colors = ["Black", "Red", "Green", "Yellow", "Blue", "Purple", "Cyan", "White"]
    return colors.randomElement() ?? "Black"
}

func isGoodPassword(password: String) -> Bool {
    guard password.count >= 16 else {
        return false
    }
    var seenCharacters = ""
    for character in password {
        if seenCharacters.contains(character) {
            return false
        }
        seenCharacters.append(character)
    }
    guard password.contains(/\d/) else {
        return false
    }
    return true
}

func randomGoodPassword() -> String {
    while true {
        let password = randomHumanString()
        if isGoodPassword(password: password) {
            return password
        }
    }
}

func getOrientation() -> UIDeviceOrientation {
    let orientation = UIDevice.current.orientation
    if orientation != .unknown {
        return orientation
    }
    let interfaceOrientation = UIApplication.shared.connectedScenes
        .first(where: { $0 is UIWindowScene })
        .flatMap { $0 as? UIWindowScene }?.interfaceOrientation
    switch interfaceOrientation {
    case .landscapeLeft:
        return .landscapeRight
    case .landscapeRight:
        return .landscapeLeft
    default:
        return .unknown
    }
}

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
    if ProcessInfo().isiOSAppOnMac {
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

func hasUltraWideBackCamera() -> Bool {
    return AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back) != nil
}

func getBestBackCameraDevice() -> AVCaptureDevice? {
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

func getBestFrontCameraDevice() -> AVCaptureDevice? {
    return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
}

func getBestBackCameraId() -> String {
    guard let device = getBestBackCameraDevice() else {
        return ""
    }
    return device.uniqueID
}

func getBestFrontCameraId() -> String {
    guard let device = getBestFrontCameraDevice() else {
        return ""
    }
    return device.uniqueID
}

func openUrl(url: String) {
    UIApplication.shared.open(URL(string: url)!)
}

extension UIDevice {
    static func vibrate() {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }
}

extension URL {
    var attributes: [FileAttributeKey: Any]? {
        do {
            return try FileManager.default.attributesOfItem(atPath: path)
        } catch {
            logger.info("file-system: Failed to get attributes for file \(self)")
        }
        return nil
    }

    var fileSize: UInt64 {
        return attributes?[.size] as? UInt64 ?? UInt64(0)
    }

    func remove() {
        do {
            try FileManager.default.removeItem(at: self)
        } catch {
            logger.info("file-system: Failed to remove file \(self)")
        }
    }
}

private var thumbnails: [URL: UIImage] = [:]

func createThumbnail(path: URL) -> UIImage? {
    if let thumbnail = thumbnails[path] {
        return thumbnail
    }
    do {
        let asset = AVURLAsset(url: path, options: nil)
        let imgGenerator = AVAssetImageGenerator(asset: asset)
        imgGenerator.appliesPreferredTrackTransform = true
        let cgImage = try imgGenerator.copyCGImage(at: CMTimeMake(value: 0, timescale: 1), actualTime: nil)
        let thumbnail = UIImage(cgImage: cgImage)
        thumbnails[path] = thumbnail
        return thumbnail
    } catch {
        logger.info("Failed to create thumbnail with error \(error)")
        return nil
    }
}

extension SettingsPrivacyRegion {
    func contains(coordinate: CLLocationCoordinate2D) -> Bool {
        cos(toRadians(degrees: latitude - coordinate.latitude)) >
            cos(toRadians(degrees: latitudeDelta / 2.0)) &&
            cos(toRadians(degrees: longitude - coordinate.longitude)) >
            cos(toRadians(degrees: longitudeDelta / 2.0))
    }
}

func toRadians(degrees: Double) -> Double {
    return degrees * .pi / 180
}

func toLatitudeDeltaDegrees(meters: Double) -> Double {
    return 360 * meters / 40_075_000
}

func toLongitudeDeltaDegrees(meters: Double, latitudeDegrees: Double) -> Double {
    return 360 * meters / (40_075_000 * cos(toRadians(degrees: latitudeDegrees)))
}

extension CLLocationCoordinate2D {
    func translateMeters(x: Double, y: Double) -> CLLocationCoordinate2D {
        let latitudeDelta = toLatitudeDeltaDegrees(meters: y)
        var newLatitude = (latitude < 0 ? 360 + latitude : latitude) + latitudeDelta
        newLatitude -= Double(360 * (Int(newLatitude) / 360))
        if newLatitude > 270 {
            newLatitude -= 360
        } else if newLatitude > 90 {
            newLatitude = 180 - newLatitude
        }
        let longitudeDelta = toLongitudeDeltaDegrees(meters: x, latitudeDegrees: latitude)
        var newLongitude = (longitude < 0 ? 360 + longitude : longitude) + longitudeDelta
        newLongitude -= Double(360 * (Int(newLongitude) / 360))
        if newLongitude > 180 {
            newLongitude = newLongitude - 360
        }
        return .init(latitude: newLatitude, longitude: newLongitude)
    }
}

extension MKCoordinateRegion: @retroactive Equatable {
    public static func == (lhs: MKCoordinateRegion, rhs: MKCoordinateRegion) -> Bool {
        if lhs.center.latitude != rhs.center.latitude || lhs.center.longitude != rhs.center.longitude {
            return false
        }
        if lhs.span.latitudeDelta != rhs.span.latitudeDelta || lhs.span.longitudeDelta != rhs.span
            .longitudeDelta
        {
            return false
        }
        return true
    }
}

struct WidgetCrop {
    let position: CGPoint
    let crop: CGRect
}

func hasAppleLog() -> Bool {
    if #available(iOS 17.0, *) {
        for format in getBestBackCameraDevice()?.formats ?? []
            where format.supportedColorSpaces.contains(.appleLog)
        {
            return true
        }
    }
    return false
}

func factorToIso(device: AVCaptureDevice, factor: Float) -> Float {
    var iso = device.activeFormat.minISO + (device.activeFormat.maxISO - device.activeFormat.minISO) * factor
        .clamped(to: 0 ... 1)
    if !iso.isFinite {
        iso = 0
    }
    return iso
}

func factorFromIso(device: AVCaptureDevice, iso: Float) -> Float {
    var factor = (iso - device.activeFormat.minISO) /
        (device.activeFormat.maxISO - device.activeFormat.minISO)
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

func makeAudioCodecString() -> String {
    return "AAC"
}

extension MTILayer {
    convenience init(content: MTIImage, position: CGPoint) {
        self.init(
            content: content,
            layoutUnit: .pixel,
            position: position,
            size: content.size,
            rotation: 0,
            opacity: 1,
            blendMode: .normal
        )
    }
}

func isValidAudioBitrate(bitrate: Int) -> Bool {
    guard bitrate >= 32000, bitrate <= 320_000 else {
        return false
    }
    guard bitrate % 32000 == 0 else {
        return false
    }
    return true
}

func currentPresentationTimeStamp() -> CMTime {
    return CMClockGetTime(CMClockGetHostTimeClock())
}

func utcTimeDeltaFromNow(to: Double) -> Double {
    return Date(timeIntervalSince1970: to).timeIntervalSinceNow
}

func emojiFlag(country: String) -> String {
    let base: UInt32 = 127_397
    var emote = ""
    for ch in country.unicodeScalars {
        emote.unicodeScalars.append(UnicodeScalar(base + ch.value)!)
    }
    return emote
}

func isPhone() -> Bool {
    return UIDevice.current.userInterfaceIdiom == .phone
}

func isPad() -> Bool {
    return UIDevice.current.userInterfaceIdiom == .pad
}

func uploadImage(
    url: URL,
    paramName: String,
    fileName: String,
    image: Data,
    message: String?,
    onCompleted: @escaping (Bool) -> Void
) {
    let boundary = UUID().uuidString
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "content-type")
    var data = Data()
    if let message {
        data.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        data.append("content-disposition: form-data; name=\"content\"\r\n\r\n".data(using: .utf8)!)
        data.append(message.data(using: .utf8)!)
    }
    data.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
    data.append(
        "content-disposition: form-data; name=\"\(paramName)\"; filename=\"\(fileName)\"\r\n"
            .data(using: .utf8)!
    )
    data.append("content-type: image/jpeg\r\n\r\n".data(using: .utf8)!)
    data.append(image)
    data.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
    URLSession.shared.uploadTask(with: request, from: data, completionHandler: { _, response, _ in
        onCompleted(response?.http?.isSuccessful == true)
    }).resume()
}

func formatCommercialStartedDuration(seconds: Int) -> String {
    let minutes = seconds / 60
    if minutes * 60 == seconds {
        if minutes == 1 {
            return "1 minute"
        } else {
            return "\(minutes) minutes"
        }
    } else {
        return "\(seconds) seconds"
    }
}

struct HttpProxy {
    var host: String
    var port: UInt16
}

extension CGSize {
    func maximum() -> CGFloat {
        return max(height, width)
    }
}

func getCpuUsage() -> Float {
    var result: Int32
    var threadList = UnsafeMutablePointer<UInt32>.allocate(capacity: 1)
    var threadCount = UInt32(MemoryLayout<mach_task_basic_info_data_t>.size / MemoryLayout<natural_t>.size)
    var threadInfo = thread_basic_info()
    result = withUnsafeMutablePointer(to: &threadList) {
        $0.withMemoryRebound(to: thread_act_array_t?.self, capacity: 1) {
            task_threads(mach_task_self_, $0, &threadCount)
        }
    }
    if result != KERN_SUCCESS {
        return 0
    }
    return (0 ..< Int(threadCount)).compactMap { index -> Float? in
        var threadInfoCount = UInt32(THREAD_INFO_MAX)
        result = withUnsafeMutablePointer(to: &threadInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                thread_info(threadList[index], UInt32(THREAD_BASIC_INFO), $0, &threadInfoCount)
            }
        }
        if result != KERN_SUCCESS { return nil }
        let isIdle = threadInfo.flags == TH_FLAGS_IDLE
        return !isIdle ? (Float(threadInfo.cpu_usage) / Float(TH_USAGE_SCALE)) * 100 : nil
    }.reduce(0, +)
}
