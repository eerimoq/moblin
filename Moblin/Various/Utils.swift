import AVKit
import CoreMotion
import MapKit
import MetalPetal
import Network
import SwiftUI
import WeatherKit

let sliderValuePercentageWidth = 60.0
let epsilon = 0.00001

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
    case .vTuber:
        return "person.crop.circle"
    case .pngTuber:
        return "person.crop.circle.dashed"
    case .snapshot:
        return "camera.aperture"
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

func hasUltraWideBackCamera() -> Bool {
    return AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back) != nil
}

func hasTripleBackCamera() -> Bool {
    return AVCaptureDevice.default(.builtInTripleCamera, for: .video, position: .back) != nil
}

func hasDualBackCamera() -> Bool {
    return AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) != nil
}

func hasWideDualBackCamera() -> Bool {
    return AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back) != nil
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

func getDefaultBackCameraPosition() -> SettingsSceneCameraPosition {
    if hasTripleBackCamera() {
        return .backTripleLowEnergy
    } else if hasWideDualBackCamera() {
        return .backWideDualLowEnergy
    } else if hasDualBackCamera() {
        return .backDualLowEnergy
    } else {
        return .back
    }
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
        try? FileManager.default.removeItem(at: self)
    }
}

private var thumbnails: [URL: UIImage] = [:]
private let thumbnailQueue = DispatchQueue(label: "com.eerimoq.moblin.thumbnail")

private func createThumbnailInner(path: URL, offset: Double) -> UIImage? {
    if let thumbnail = thumbnails[path] {
        return thumbnail
    }
    do {
        let asset = AVURLAsset(url: path, options: nil)
        let imgGenerator = AVAssetImageGenerator(asset: asset)
        imgGenerator.appliesPreferredTrackTransform = true
        let cgImage = try imgGenerator.copyCGImage(at: CMTime(seconds: offset), actualTime: nil)
        let thumbnail = UIImage(cgImage: cgImage)
        thumbnails[path] = thumbnail
        return thumbnail
    } catch {
        logger.info("Failed to create thumbnail with error \(error)")
        return nil
    }
}

func createThumbnail(path: URL, offset: Double = 0, onComplete: @escaping (UIImage?) -> Void) {
    thumbnailQueue.async {
        let image = createThumbnailInner(path: path, offset: offset)
        DispatchQueue.main.async {
            onComplete(image)
        }
    }
}

extension SettingsPrivacyRegion {
    func contains(coordinate: CLLocationCoordinate2D) -> Bool {
        cos((latitude - coordinate.latitude).toRadians()) >
            cos((latitudeDelta / 2.0).toRadians()) &&
            cos((longitude - coordinate.longitude).toRadians()) >
            cos((longitudeDelta / 2.0).toRadians())
    }
}

func toLatitudeDeltaDegrees(meters: Double) -> Double {
    return 360 * meters / 40_075_000
}

func toLongitudeDeltaDegrees(meters: Double, latitudeDegrees: Double) -> Double {
    return 360 * meters / (40_075_000 * cos(latitudeDegrees.toRadians()))
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

func isMac() -> Bool {
    return ProcessInfo().isiOSAppOnMac
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

    func isPortrait() -> Bool {
        return height > width
    }
}

class ResourceUsage {
    private var previousTime: ContinuousClock.Instant?
    private var previousUsage: rusage?
    private var cpuUsage: Float = 0

    func update(now: ContinuousClock.Instant) {
        var usage = rusage()
        guard getrusage(RUSAGE_SELF, &usage) == 0 else {
            return
        }
        if let previousTime, let previousUsage {
            let systemTime = usage.ru_stime.milliseconds - previousUsage.ru_stime.milliseconds
            let userTime = usage.ru_utime.milliseconds - previousUsage.ru_utime.milliseconds
            let time = Float(systemTime + userTime)
            cpuUsage = 100 * time / Float(previousTime.duration(to: now).milliseconds)
        }
        previousTime = now
        previousUsage = usage
    }

    func getCpuUsage() -> Float {
        return cpuUsage
    }
}

extension FileManager {
    func ids(directory: String) -> [UUID] {
        var ids: [UUID] = []
        for file in (try? contentsOfDirectory(atPath: directory)) ?? [] {
            guard let id = UUID(uuidString: file) else {
                continue
            }
            ids.append(id)
        }
        return ids
    }

    func idsBeforeDot(directory: String) -> [UUID] {
        var ids: [UUID] = []
        for file in (try? contentsOfDirectory(atPath: directory)) ?? [] {
            let parts = file.components(separatedBy: ".")
            guard parts.count > 1, let id = UUID(uuidString: parts[0]) else {
                continue
            }
            ids.append(id)
        }
        return ids
    }
}

final class NWConnectionWithId: Hashable, Equatable {
    let id: String
    let connection: NWConnection

    init(connection: NWConnection) {
        self.connection = connection
        id = UUID().uuidString
    }

    static func == (lhs: NWConnectionWithId, rhs: NWConnectionWithId) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension NWConnection.ContentContext {
    func webSocketOperation() -> NWProtocolWebSocket.Opcode? {
        let definitions = protocolMetadata(definition: NWProtocolWebSocket.definition) as? Network.NWProtocolWebSocket
            .Metadata
        return definitions?.opcode
    }
}

extension NWConnection {
    func sendWebSocket(data: Data?, opcode: NWProtocolWebSocket.Opcode) {
        let metadata = NWProtocolWebSocket.Metadata(opcode: opcode)
        let context = NWConnection.ContentContext(identifier: "context", metadata: [metadata])
        send(content: data, contentContext: context, isComplete: true, completion: .idempotent)
    }
}

func getAvailableDiskSpace() -> UInt64? {
    guard let attributes = try? FileManager.default.attributesOfFileSystem(forPath: URL.homeDirectory.path()) else {
        return nil
    }
    return attributes[.systemFreeSize] as? UInt64
}

func deleteTrash() {
    let folders = [
        URL.temporaryDirectory,
        URL.documentsDirectory.appending(component: ".Trash"),
    ]
    for folder in folders {
        guard let paths = try? FileManager.default.contentsOfDirectory(atPath: folder.path()) else {
            continue
        }
        for path in paths {
            try? FileManager.default.removeItem(atPath: path)
        }
    }
}

func generateQrCode(from string: String) -> UIImage? {
    let data = string.data(using: .utf8)
    let filter = CIFilter.qrCodeGenerator()
    filter.message = data!
    filter.correctionLevel = "M"
    guard let image = filter.outputImage else {
        return nil
    }
    let output = image.scaled(x: 5, y: 5)
    let context = CIContext()
    guard let cgImage = context.createCGImage(output, from: output.extent) else {
        return nil
    }
    return UIImage(cgImage: cgImage)
}

func createAndGetDirectory(name: String) -> URL {
    let directory = URL.documentsDirectory.appending(component: name)
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}

func tryGetToastSubTitle(error: Error) -> String? {
    if let error = error as? AVError {
        return error._nsError.localizedFailureReason
    } else {
        return nil
    }
}

extension CMTime {
    init(seconds: Double) {
        self = CMTime(seconds: seconds, preferredTimescale: 1000)
    }
}

extension UnsafeMutableRawBufferPointer {
    func writeUInt8(_ value: UInt8, offset: Int) {
        self[offset + 0] = value
    }

    func writeUInt16(_ value: UInt16, offset: Int) {
        self[offset + 0] = UInt8((value >> 8) & 0xFF)
        self[offset + 1] = UInt8(value & 0xFF)
    }

    func writeUInt32(_ value: UInt32, offset: Int) {
        self[offset + 0] = UInt8(value >> 24)
        self[offset + 1] = UInt8((value >> 16) & 0xFF)
        self[offset + 2] = UInt8((value >> 8) & 0xFF)
        self[offset + 3] = UInt8(value & 0xFF)
    }
}

extension UnsafeRawBufferPointer {
    func readUInt16(offset: Int) -> UInt16 {
        var value: UInt16 = 0
        value |= UInt16(self[offset + 0]) << 8
        value |= UInt16(self[offset + 1]) << 0
        return value
    }

    func readUInt32(offset: Int) -> UInt32 {
        var value: UInt32 = 0
        value |= UInt32(self[offset + 0]) << 24
        value |= UInt32(self[offset + 1]) << 16
        value |= UInt32(self[offset + 2]) << 8
        value |= UInt32(self[offset + 3]) << 0
        return value
    }
}

protocol Named {
    var name: String { get }
}

func makeUniqueName<T: Named>(name: String, existingNames: [T]) -> String {
    let existingNames = existingNames.map { $0.name }
    if !existingNames.contains(name) {
        return name
    }
    var number = 1
    while true {
        let nameCandidate = "\(name) \(number)"
        if !existingNames.contains(nameCandidate) {
            return nameCandidate
        }
        number += 1
    }
}

func createSpeechSynthesizer() -> AVSpeechSynthesizer {
    let synthesizer = AVSpeechSynthesizer()
    synthesizer.usesApplicationAudioSession = false
    return synthesizer
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

func makeRecordingPath(recordingPath: Data) -> URL? {
    var isStale = false
    return try? URL(resolvingBookmarkData: recordingPath, bookmarkDataIsStale: &isStale)
}

func zoomToFieldOfView(zoom: Float, zoomOne: Float = .pi / 2) -> Float {
    return 2 * atan(tan(zoomOne / 2) / zoom)
}

func fieldOfViewToZoom(fieldOfView: Float, zoomOne: Float = .pi / 2) -> Float {
    return tan(zoomOne / 2) / tan(fieldOfView / 2)
}

extension Locale.Language {
    func identifier() -> String? {
        guard let languageCode else {
            return nil
        }
        var identifier = "\(languageCode)"
        if let script {
            identifier += "-\(script)"
        }
        if let region {
            identifier += "-\(region)"
        }
        return identifier
    }

    func name() -> String {
        guard let identifier = identifier() else {
            return "Unknown"
        }
        return NSLocale.current.localizedString(forIdentifier: identifier) ?? "Unknown"
    }
}
