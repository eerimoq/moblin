import AVFoundation
import AVKit
import MapKit
import Network
import SwiftUI

let iconWidth = 32.0
let controlBarButtonSize = 40.0
let controlBarWidthDefault = 100.0
let controlBarWidthBigQuickButtons = 150.0
let controlBarQuickButtonNameSize = 10.0
let controlBarQuickButtonNameSingleColumnSize = 12.0
let controlBarQuickButtonSingleQuickButtonSize = 60.0
let stealthModeButtonSize = 80.0
let maximumNumberOfWatchChatMessages = 50
let personalHotspotLocalAddress = "172.20.10.1"
let backgroundColor = Color(white: 0, opacity: 0.4)
let scoreboardBlueColor = RgbColor(red: 0x0B, green: 0x10, blue: 0xAC).color()

extension String: @retroactive Error {}

// Do we have a race condition? How to fix?
extension CMSampleBuffer: @unchecked @retroactive Sendable {}
extension CVBuffer: @unchecked @retroactive Sendable {}

extension String {
    func trim() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func substring(begin: Int, end: Int) -> String {
        let beginIndex = index(startIndex, offsetBy: begin)
        let endIndex = index(startIndex, offsetBy: end)
        return String(self[beginIndex ..< endIndex])
    }
}

extension Substring {
    func trim() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

func makeRtmpUri(url: String) -> String {
    let parts = url.split(separator: "/", omittingEmptySubsequences: false)
    if parts.isEmpty {
        return ""
    }
    return parts[..<(parts.count - 1)].joined(separator: "/")
}

func makeRtmpStreamKey(url: String) -> String {
    let parts = url.split(separator: "/")
    if parts.isEmpty {
        return ""
    }
    return String(parts[parts.count - 1])
}

func cleanUrl(url value: String) -> String {
    let stripped = value.replacingOccurrences(of: " ", with: "")
    guard var components = URLComponents(string: stripped) else {
        return stripped
    }
    components.scheme = components.scheme?.lowercased()
    return components.string!
}

func replaceSensitive(value: String, sensitive: Bool) -> String {
    if sensitive {
        value.replacing(/./, with: "•")
    } else {
        value
    }
}

var countFormatter: IntegerFormatStyle<Int> {
    IntegerFormatStyle<Int>().notation(.compactName)
}

var sizeFormatter: ByteCountFormatter {
    let formatter = ByteCountFormatter()
    formatter.allowsNonnumericFormatting = false
    formatter.countStyle = .decimal
    return formatter
}

var speedFormatterValue: ByteCountFormatter {
    let formatter = ByteCountFormatter()
    formatter.allowsNonnumericFormatting = false
    formatter.countStyle = .decimal
    formatter.includesUnit = false
    return formatter
}

var speedFormatterUnit: ByteCountFormatter {
    let formatter = ByteCountFormatter()
    formatter.allowsNonnumericFormatting = false
    formatter.includesCount = false
    return formatter
}

func formatBytesPerSecond(speed: Int64) -> String {
    let value = speedFormatterValue.string(fromByteCount: speed)
    var unit = speedFormatterUnit.string(fromByteCount: speed)
    unit = unit.replacingOccurrences(of: "bytes", with: "bps")
    unit = unit.replacingOccurrences(of: "byte", with: "bps")
    if unit.count == 2 {
        unit = "\(unit.remove(at: unit.startIndex))bps"
    }
    return "\(value) \(unit)"
}

private func createUptimeFormatter() -> DateComponentsFormatter {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.day, .hour, .minute, .second]
    formatter.unitsStyle = .abbreviated
    return formatter
}

let uptimeFormatter = createUptimeFormatter()

private func createDigitalClockFormatter() -> DateFormatter {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    formatter.amSymbol = ""
    formatter.pmSymbol = ""
    return formatter
}

let digitalClockFormatter = createDigitalClockFormatter()

private func createDurationFormatter() -> DateComponentsFormatter {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.day, .hour, .minute]
    formatter.unitsStyle = .abbreviated
    return formatter
}

let durationFormatter = createDurationFormatter()

func formatDate(_ dateString: String) -> String? {
    try? Date.ISO8601FormatStyle()
        .parse(dateString)
        .formatted(date: .abbreviated, time: .omitted)
}

extension Duration {
    func format() -> String {
        durationFormatter.string(from: Double(components.seconds))!
    }

    func formatWithSeconds() -> String {
        uptimeFormatter.string(from: Double(components.seconds))!
    }
}

private func createFullDurationFormatter() -> DateComponentsFormatter {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.day, .hour, .minute, .second]
    formatter.unitsStyle = .full
    formatter.referenceDate = Date(timeIntervalSince1970: 0)
    return formatter
}

private let fullDurationFormatter = createFullDurationFormatter()

func formatFullDuration(seconds: Int) -> String {
    fullDurationFormatter.string(from: Double(seconds)) ?? ""
}

private func createSpeedFormatter() -> MeasurementFormatter {
    let formatter = MeasurementFormatter()
    formatter.numberFormatter.maximumFractionDigits = 0
    return formatter
}

func format(speed: Double) -> String {
    let measurement = Measurement(value: max(speed, 0), unit: UnitSpeed.metersPerSecond)
    return createSpeedFormatter().string(from: measurement)
}

private func createWindSpeedFormatter() -> MeasurementFormatter {
    let formatter = MeasurementFormatter()
    formatter.numberFormatter.maximumFractionDigits = 0
    formatter.unitOptions = .providedUnit
    return formatter
}

func formatWindSpeed(speed: Measurement<UnitSpeed>) -> String {
    let unit: UnitSpeed = Locale.current.measurementSystem == .metric ? .metersPerSecond : .milesPerHour
    return createWindSpeedFormatter().string(from: speed.converted(to: unit))
}

func formatWindAndGustSpeed(speed: Measurement<UnitSpeed>, gust: Measurement<UnitSpeed>) -> String {
    let unit: UnitSpeed = Locale.current.measurementSystem == .metric ? .metersPerSecond : .milesPerHour
    let speed = Int(speed.converted(to: unit).value)
    let gust = Int(gust.converted(to: unit).value)
    return "\(speed) (\(gust)) \(unit.symbol)"
}

func formatPace(speed: Double) -> String {
    let unit: UnitLength = Locale.current.measurementSystem == .metric ? .kilometers : .miles
    let pace: String
    if speed > 0 {
        let metersPerUnit = Measurement(value: 1, unit: unit).converted(to: .meters).value
        let secondsPerUnit = Int(metersPerUnit / speed)
        let minutes = secondsPerUnit / 60
        let seconds = secondsPerUnit % 60
        pace = String(format: "%d:%02d", minutes, seconds)
    } else {
        pace = "-"
    }
    return String(localized: "\(pace) min/\(unit.symbol)")
}

private func createDistanceFormatter() -> LengthFormatter {
    let formatter = LengthFormatter()
    formatter.numberFormatter.maximumFractionDigits = 1
    return formatter
}

func format(distance: Double) -> String {
    createDistanceFormatter().string(fromMeters: distance)
}

private func createAltitudeFormatter() -> MeasurementFormatter {
    let formatter = MeasurementFormatter()
    formatter.unitOptions = .providedUnit
    formatter.numberFormatter.maximumFractionDigits = 0
    return formatter
}

func format(altitude: Double) -> String {
    var measurement = Measurement(value: altitude, unit: UnitLength.meters)
    if UnitLength(forLocale: .current) == .feet {
        measurement = measurement.converted(to: .feet)
    }
    return createAltitudeFormatter().string(from: measurement)
}

extension ProcessInfo.ThermalState {
    func string() -> String {
        switch self {
        case .nominal:
            "nominal"
        case .fair:
            "fair"
        case .serious:
            "serious"
        case .critical:
            "critical"
        default:
            "unknown"
        }
    }
}

func appVersion() -> String {
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
}

func formatOneDecimal(_ value: Float) -> String {
    String(format: "%.01f", value)
}

func formatTwoDecimals(_ value: Double) -> String {
    String(format: "%.02f", value)
}

func formatThreeDecimals(_ value: Double) -> String {
    String(format: "%.03f", value)
}

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}

func bitrateToMbps(bitrate: UInt32) -> Float {
    Float(bitrate) / 1_000_000
}

func bitrateFromMbps(bitrate: Float) -> UInt32 {
    UInt32(bitrate * 1_000_000)
}

extension FloatingPoint {
    func toRadians() -> Self {
        self * .pi / 180
    }

    func toDegrees() -> Self {
        self * 180 / .pi
    }
}

func diffAngles<T: FloatingPoint>(_ one: T, _ two: T) -> T {
    let diff = abs((one - two).toDegrees())
    return min(diff, 360 - diff)
}

extension URLResponse {
    var http: HTTPURLResponse? {
        self as? HTTPURLResponse
    }
}

extension HTTPURLResponse {
    var isSuccessful: Bool {
        200 ... 299 ~= statusCode
    }

    var isNotFound: Bool {
        statusCode == 404
    }

    var isUnauthorized: Bool {
        statusCode == 401
    }
}

func httpGet(from: URL) async throws -> (Data, HTTPURLResponse) {
    let (data, response) = try await URLSession.shared.data(from: from)
    if let response = response.http {
        return (data, response)
    } else {
        throw "Not an HTTP response"
    }
}

func httpGet(request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    let (data, response) = try await URLSession.shared.data(for: request)
    if let response = response.http {
        return (data, response)
    } else {
        throw "Not an HTTP response"
    }
}

extension URLRequest {
    mutating func setAuthorization(_ value: String) {
        setValue(value, forHTTPHeaderField: "Authorization")
    }

    mutating func setContentType(_ value: String) {
        setValue(value, forHTTPHeaderField: "Content-Type")
    }
}

let smallFont = Font.system(size: 13)

extension UInt64 {
    func formatBytes() -> String {
        sizeFormatter.string(fromByteCount: Int64(self))
    }
}

extension ProcessInfo.ThermalState {
    func color() -> Color {
        switch self {
        case .nominal:
            .white
        case .fair:
            .white
        case .serious:
            .yellow
        case .critical:
            .red
        default:
            .pink
        }
    }
}

extension ExpressibleByIntegerLiteral {
    init(data: Data) {
        let diff: Int = MemoryLayout<Self>.size - data.count
        if diff > 0 {
            var buffer = Data(repeating: 0, count: diff)
            buffer.append(data)
            self = buffer.withUnsafeBytes { $0.baseAddress!.assumingMemoryBound(to: Self.self).pointee }
            return
        }
        self = data.withUnsafeBytes { $0.baseAddress!.assumingMemoryBound(to: Self.self).pointee }
    }
}

extension UnsignedInteger {
    func isBitSet(index: Int) -> Bool {
        ((self >> index) & 1) == 1
    }
}

extension Data {
    init(hexString: String) throws {
        guard hexString.count.isMultiple(of: 2) else {
            throw "Not multiple of 2"
        }
        var bytes = Data()
        var index = hexString.startIndex
        for _ in stride(from: 0, to: hexString.count, by: 2) {
            var value = String(hexString[index])
            index = hexString.index(after: index)
            value += String(hexString[index])
            index = hexString.index(after: index)
            guard let value = UInt8(value, radix: 16) else {
                throw "Invalid radix 16 data \(value)"
            }
            bytes.append(value)
        }
        self.init(bytes)
    }

    func hexString() -> String {
        map { String(format: "%02hhx", $0) }.joined()
    }

    func getInt64Be(offset: Int = 0) -> Int64 {
        Int64(bitPattern: UInt64(getFourBytesBe(offset: offset)) << 32 |
            UInt64(getFourBytesBe(offset: offset + 4)))
    }

    func getUInt32Be(offset: Int = 0) -> UInt32 {
        withUnsafeBytes { data in
            data.load(fromByteOffset: offset, as: UInt32.self)
        }.bigEndian
    }

    func getUInt16Be(offset: Int = 0) -> UInt16 {
        withUnsafeBytes { data in
            data.load(fromByteOffset: offset, as: UInt16.self)
        }.bigEndian
    }

    func getThreeBytesBe(offset: Int = 0) -> UInt32 {
        UInt32(self[offset]) << 16 | UInt32(self[offset + 1]) << 8 | UInt32(self[offset + 2])
    }

    func getFourBytesBe(offset: Int = 0) -> UInt32 {
        UInt32(self[offset]) << 24 | UInt32(self[offset + 1]) << 16 | UInt32(self[offset + 2]) <<
            8 |
            UInt32(self[offset + 3])
    }

    func getFourBytesLe(offset: Int = 0) -> UInt32 {
        UInt32(self[offset + 3]) << 24 | UInt32(self[offset + 2]) << 16 |
            UInt32(self[offset + 1]) <<
            8 |
            UInt32(self[offset + 0])
    }

    mutating func setUInt16Be(value: UInt16, offset: Int = 0) {
        withUnsafeMutableBytes { data in data.storeBytes(
            of: value.bigEndian,
            toByteOffset: offset,
            as: UInt16.self
        ) }
    }

    mutating func setUInt32Be(value: UInt32, offset: Int = 0) {
        withUnsafeMutableBytes { data in data.storeBytes(
            of: value.bigEndian,
            toByteOffset: offset,
            as: UInt32.self
        ) }
    }

    mutating func setInt64Be(value: Int64, offset: Int = 0) {
        withUnsafeMutableBytes { data in data.storeBytes(
            of: value.bigEndian,
            toByteOffset: offset,
            as: Int64.self
        ) }
    }

    func makeBlockBuffer(advancedBy: Int = 0) -> CMBlockBuffer? {
        var blockBuffer: CMBlockBuffer?
        guard advancedBy < count else {
            return nil
        }
        let length = count - advancedBy
        return withUnsafeBytes { (buffer: UnsafeRawBufferPointer) -> CMBlockBuffer? in
            guard let baseAddress = buffer.baseAddress else {
                return nil
            }
            guard CMBlockBufferCreateWithMemoryBlock(
                allocator: kCFAllocatorDefault,
                memoryBlock: nil,
                blockLength: length,
                blockAllocator: nil,
                customBlockSource: nil,
                offsetToData: 0,
                dataLength: length,
                flags: 0,
                blockBufferOut: &blockBuffer
            ) == noErr, let blockBuffer else {
                return nil
            }
            guard CMBlockBufferReplaceDataBytes(
                with: baseAddress.advanced(by: advancedBy),
                blockBuffer: blockBuffer,
                offsetIntoDestination: 0,
                dataLength: length
            ) == noErr else {
                return nil
            }
            return blockBuffer
        }
    }
}

private let cameraPositionRtmp = "(RTMP)"
private let cameraPositionSrtla = "(SRT(LA))"
private let cameraPositionRist = "(RIST)"
private let cameraPositionRtsp = "(RTSP)"
private let cameraPositionWhip = "(WHIP)"
private let cameraPositionWhep = "(WHEP)"
private let cameraPositionMediaPlayer = "(Media player)"

func rtmpCamera(name: String) -> String {
    "\(name) \(cameraPositionRtmp)"
}

func isRtmpCameraOrMic(camera: String) -> Bool {
    camera.hasSuffix(cameraPositionRtmp)
}

func srtlaCamera(name: String) -> String {
    "\(name) \(cameraPositionSrtla)"
}

func isSrtlaCameraOrMic(camera: String) -> Bool {
    camera.hasSuffix(cameraPositionSrtla)
}

func ristCamera(name: String) -> String {
    "\(name) \(cameraPositionRist)"
}

func isRistCameraOrMic(camera: String) -> Bool {
    camera.hasSuffix(cameraPositionRist)
}

func rtspCamera(name: String) -> String {
    "\(name) \(cameraPositionRtsp)"
}

func isRtspCameraOrMic(camera: String) -> Bool {
    camera.hasSuffix(cameraPositionRtsp)
}

func whipCamera(name: String) -> String {
    "\(name) \(cameraPositionWhip)"
}

func isWhipCameraOrMic(camera: String) -> Bool {
    camera.hasSuffix(cameraPositionWhip)
}

func whepCamera(name: String) -> String {
    "\(name) \(cameraPositionWhep)"
}

func isWhepCameraOrMic(camera: String) -> Bool {
    camera.hasSuffix(cameraPositionWhep)
}

func mediaPlayerCamera(name: String) -> String {
    "\(name) \(cameraPositionMediaPlayer)"
}

func isMediaPlayerCameraOrMic(camera: String) -> Bool {
    camera.hasSuffix(cameraPositionMediaPlayer)
}

func formatAudioLevelDb(level: Float) -> String {
    String(localized: "\(Int(level)) dB,")
}

func formatAudioLevel(level: Float) -> String {
    if level.isNaN {
        "Muted,"
    } else if level == .infinity {
        "Unknown,"
    } else {
        formatAudioLevelDb(level: level)
    }
}

func formatAudioLevelChannels(channels: Int) -> String {
    String(localized: " \(channels) ch")
}

func formatAudioLevelSampleRate(sampleRate: Double) -> String {
    String(localized: " \(Int(sampleRate / 1000)) kHz")
}

let noValue = ""

func urlImage(interfaceType: NWInterface.InterfaceType) -> String {
    switch interfaceType {
    case .other:
        return "questionmark"
    case .wifi:
        return "wifi"
    case .cellular:
        return "antenna.radiowaves.left.and.right"
    case .wiredEthernet:
        return "cable.connector"
    case .loopback:
        return "questionmark"
    @unknown default:
        return "questionmark"
    }
}

func sleep(seconds: Int) async throws {
    try await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
}

func sleep(milliSeconds: Int) async throws {
    try await Task.sleep(nanoseconds: UInt64(milliSeconds) * 1_000_000)
}

let moblinAppGroup = "group.com.eerimoq.Moblin"

extension Duration {
    var microseconds: Int64 {
        components.seconds * 1_000_000 + components.attoseconds / 1_000_000_000_000
    }

    var milliseconds: Int64 {
        components.seconds * 1000 + components.attoseconds / 1_000_000_000_000_000
    }

    var seconds: Double {
        Double(milliseconds) / 1000
    }
}

extension String {
    static func fromUtf8(data: Data) -> String {
        guard let text = String(data: data, encoding: .utf8) else {
            fatalError("Not UTF-8")
        }
        return text
    }

    var utf8Data: Data {
        Data(utf8)
    }
}

class RgbColor: Codable, Equatable {
    static func == (lhs: RgbColor, rhs: RgbColor) -> Bool {
        lhs.red == rhs.red && lhs.green == rhs.green && lhs.blue == rhs.blue && lhs.opacity == rhs
            .opacity
    }

    static let white = RgbColor(red: 255, green: 255, blue: 255)
    static let black = RgbColor(red: 0, green: 0, blue: 0)

    var red: Int = 0
    var green: Int = 0
    var blue: Int = 0
    // May be nil
    var opacity: Double?

    init(red: Int, green: Int, blue: Int, opacity: Double? = nil) {
        self.red = red
        self.green = green
        self.blue = blue
        self.opacity = opacity
    }

    func makeReadableOnDarkBackground() -> RgbColor {
        let threshold = 100
        guard red < threshold, green < threshold, blue < threshold else {
            return self
        }
        return .init(red: red + threshold, green: green + threshold, blue: blue + threshold)
    }

    func withOpacity(opacity: Double?) -> RgbColor {
        RgbColor(red: red, green: green, blue: blue, opacity: opacity)
    }

    func toHex() -> String {
        String(format: "#%02x%02x%02x", red, green, blue)
    }

    static func fromHex(string: String) -> RgbColor? {
        if let colorNumber = Int(string.suffix(6), radix: 16) {
            RgbColor(
                red: (colorNumber >> 16) & 0xFF,
                green: (colorNumber >> 8) & 0xFF,
                blue: colorNumber & 0xFF
            )
        } else {
            nil
        }
    }
}

extension RgbColor {
    private func colorScale(_ color: Int) -> Double {
        Double(color) / 255
    }

    func color() -> Color {
        Color(
            red: colorScale(red),
            green: colorScale(green),
            blue: colorScale(blue),
            opacity: opacity ?? 1.0
        )
    }

    func hue() -> Double {
        let color = UIColor(red: colorScale(red), green: colorScale(green), blue: colorScale(blue), alpha: 1)
        var hue: CGFloat = 0
        color.getHue(&hue, saturation: nil, brightness: nil, alpha: nil)
        return hue
    }
}

extension Color {
    func toRgb() -> RgbColor? {
        guard let components = UIColor(self).cgColor.components else {
            return nil
        }
        guard components.count >= 3 else {
            return nil
        }
        return RgbColor(
            red: Int(255 * components[0]),
            green: Int(255 * components[1]),
            blue: Int(255 * components[2]),
            opacity: components.count == 4 ? components[3] : 1.0
        )
    }

    /// Returns an RgbColor within the standard range. meaning the value is clamped to be in between 0 and 255
    func toStandardRgb() -> RgbColor? {
        guard let extendedRgbColor = toRgb() else {
            return nil
        }
        return RgbColor(
            red: min(max(extendedRgbColor.red, 0), 255),
            green: min(max(extendedRgbColor.green, 0), 255),
            blue: min(max(extendedRgbColor.blue, 0), 255),
            opacity: extendedRgbColor.opacity
        )
    }
}

func isSetWin(first: Int, second: Int) -> Bool {
    if first == 7 {
        return true
    }
    if first == 6, second <= 4 {
        return true
    }
    return false
}

extension KeyedEncodingContainer {
    mutating func encode(_ key: KeyedEncodingContainer<K>.Key, _ value: some Encodable) throws {
        try encode(value, forKey: key)
    }
}

extension KeyedDecodingContainer {
    func decode<T: Decodable>(_ key: KeyedDecodingContainer<K>.Key, _ type: T.Type, _ defaultValue: T) -> T {
        (try? decode(type, forKey: key)) ?? defaultValue
    }
}
