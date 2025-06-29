import AVFoundation
import AVKit
import MapKit
import Network
import SwiftUI

let iconWidth = 32.0
let controlBarButtonSize = 40.0
let controlBarWidthAccessibility = 150.0
let controlBarWidthDefault = 100.0
let controlBarQuickButtonNameSize = 10.0
let controlBarQuickButtonNameSingleColumnSize = 12.0
let controlBarQuickButtonSingleQuickButtonSize = 60.0
let stealthModeButtonSize = 80.0
let maximumNumberOfWatchChatMessages = 50
let personalHotspotLocalAddress = "172.20.10.1"
let backgroundColor = Color(white: 0, opacity: 0.4)
let scoreboardBlueColor = RgbColor(red: 0x0B, green: 0x10, blue: 0xAC).color()
let scoreboardDarkBlueColor = RgbColor(red: 0, green: 3, blue: 0x5B).color()

extension String: @retroactive Error {}

// Do we have a race condition? How to fix?
extension CMSampleBuffer: @unchecked @retroactive Sendable {}
extension CVBuffer: @unchecked @retroactive Sendable {}

extension String {
    func trim() -> String {
        return trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension Substring {
    func trim() -> String {
        return trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

func makeRtmpUri(url: String) -> String {
    guard var url = URL(string: url) else {
        return ""
    }
    var components = url.pathComponents
    if components.count < 2 {
        return ""
    }
    components.removeFirst()
    components.removeLast()
    var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)!
    let path = components.joined(separator: "/")
    urlComponents.path = "/\(path)"
    urlComponents.query = nil
    urlComponents.fragment = nil
    url = urlComponents.url!
    return "\(url)"
}

func makeRtmpStreamName(url: String) -> String {
    let parts = url.split(separator: "/")
    if parts.isEmpty {
        return ""
    }
    return String(parts[parts.count - 1])
}

func isValidRtmpUrl(url: String, rtmpStreamKeyRequired: Bool) -> String? {
    if !rtmpStreamKeyRequired {
        return nil
    }
    if makeRtmpUri(url: url) == "" {
        return String(localized: "Malformed RTMP URL")
    }
    if makeRtmpStreamName(url: url) == "" {
        return String(localized: "RTMP stream name missing")
    }
    return nil
}

func isValidSrtUrl(url: String) -> String? {
    guard let url = URL(string: url) else {
        return String(localized: "Malformed SRT(LA) URL")
    }
    if url.port == nil {
        return String(localized: "SRT(LA) port number missing")
    }
    return nil
}

func isValidRistUrl(url: String) -> String? {
    guard let url = URL(string: url) else {
        return String(localized: "Malformed RIST URL")
    }
    if url.port == nil {
        return String(localized: "RIST port number missing")
    }
    return nil
}

private func isValidIrlUrl(url: String) -> String? {
    guard URL(string: url) != nil else {
        return String(localized: "Malformed IRL URL")
    }
    return nil
}

func cleanUrl(url value: String) -> String {
    let stripped = value.replacingOccurrences(of: " ", with: "")
    guard var components = URLComponents(string: stripped) else {
        return stripped
    }
    components.scheme = components.scheme?.lowercased()
    return components.string!
}

func isValidUrl(url value: String, allowedSchemes: [String]? = nil,
                rtmpStreamKeyRequired: Bool = true) -> String?
{
    guard let url = URL(string: value) else {
        return String(localized: "Malformed URL")
    }
    if url.host() == nil {
        return String(localized: "Host missing")
    }
    guard URLComponents(url: url, resolvingAgainstBaseURL: false) != nil else {
        return String(localized: "Malformed URL")
    }
    if let allowedSchemes, let scheme = url.scheme {
        if !allowedSchemes.contains(scheme) {
            return "Only \(allowedSchemes.joined(separator: " and ")) allowed, not \(scheme)"
        }
    }
    switch url.scheme {
    case "rtmp":
        if let message = isValidRtmpUrl(url: value, rtmpStreamKeyRequired: rtmpStreamKeyRequired) {
            return message
        }
    case "rtmps":
        if let message = isValidRtmpUrl(url: value, rtmpStreamKeyRequired: rtmpStreamKeyRequired) {
            return message
        }
    case "srt":
        if let message = isValidSrtUrl(url: value) {
            return message
        }
    case "srtla":
        if let message = isValidSrtUrl(url: value) {
            return message
        }
    case "rist":
        if let message = isValidRistUrl(url: value) {
            return message
        }
    case "irl":
        if let message = isValidIrlUrl(url: value) {
            return message
        }
    case nil:
        return String(localized: "Scheme missing")
    default:
        return String(localized: "Unsupported scheme \(url.scheme!)")
    }
    return nil
}

func isValidWebSocketUrl(url value: String) -> String? {
    if value.isEmpty {
        return nil
    }
    guard let url = URL(string: value) else {
        return String(localized: "Malformed URL")
    }
    if url.host() == nil {
        return String(localized: "Host missing")
    }
    guard URLComponents(url: url, resolvingAgainstBaseURL: false) != nil else {
        return String(localized: "Malformed URL")
    }
    switch url.scheme {
    case "ws":
        break
    case "wss":
        break
    case nil:
        return String(localized: "Scheme missing")
    default:
        return String(localized: "Unsupported scheme \(url.scheme!)")
    }
    return nil
}

func schemeAndAddress(url: String) -> String {
    guard var url = URL(string: url) else {
        return ""
    }
    guard var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
    else {
        return ""
    }
    urlComponents.path = "/"
    urlComponents.query = nil
    url = urlComponents.url!
    return "\(url)..."
}

func replaceSensitive(value: String, sensitive: Bool) -> String {
    if sensitive {
        return value.replacing(/./, with: "*")
    } else {
        return value
    }
}

var countFormatter: IntegerFormatStyle<Int> {
    return IntegerFormatStyle<Int>().notation(.compactName)
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

var uptimeFormatter: DateComponentsFormatter {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.day, .hour, .minute, .second]
    formatter.unitsStyle = .abbreviated
    return formatter
}

var digitalClockFormatter: DateFormatter {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    formatter.amSymbol = ""
    formatter.pmSymbol = ""
    return formatter
}

var durationFormatter: DateComponentsFormatter {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.day, .hour, .minute]
    formatter.unitsStyle = .abbreviated
    return formatter
}

extension Duration {
    func format() -> String {
        return durationFormatter.string(from: Double(components.seconds))!
    }

    func formatWithSeconds() -> String {
        return uptimeFormatter.string(from: Double(components.seconds))!
    }
}

private var speedFormatter: MeasurementFormatter {
    let formatter = MeasurementFormatter()
    formatter.numberFormatter.maximumFractionDigits = 0
    return formatter
}

func format(speed: Double) -> String {
    return speedFormatter.string(from: NSMeasurement(
        doubleValue: max(speed, 0),
        unit: UnitSpeed.metersPerSecond
    ) as Measurement<Unit>)
}

private var distanceFormatter: LengthFormatter {
    let formatter = LengthFormatter()
    formatter.numberFormatter.maximumFractionDigits = 1
    return formatter
}

func format(distance: Double) -> String {
    return distanceFormatter.string(fromMeters: distance)
}

private var altitudeFormatter: MeasurementFormatter {
    let formatter = MeasurementFormatter()
    var options: MeasurementFormatter.UnitOptions = []
    options.insert(.providedUnit)
    formatter.unitOptions = options
    formatter.numberFormatter.maximumFractionDigits = 0
    return formatter
}

func format(altitude: Double) -> String {
    var measurement = Measurement(value: altitude, unit: UnitLength.meters)
    if UnitLength(forLocale: .current) == .feet {
        measurement = measurement.converted(to: .feet)
    }
    return altitudeFormatter.string(from: measurement)
}

extension ProcessInfo.ThermalState {
    func string() -> String {
        switch self {
        case .nominal:
            return "nominal"
        case .fair:
            return "fair"
        case .serious:
            return "serious"
        case .critical:
            return "critical"
        default:
            return "unknown"
        }
    }
}

func appVersion() -> String {
    return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
}

func formatAsInt(_ value: CGFloat) -> String {
    return String(format: "%d", Int(value))
}

func formatOneDecimal(_ value: Float) -> String {
    return String(format: "%.01f", value)
}

func formatTwoDecimals(_ value: Double) -> String {
    return String(format: "%.02f", value)
}

func formatThreeDecimals(_ value: Double) -> String {
    return String(format: "%.03f", value)
}

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}

func bitrateToMbps(bitrate: UInt32) -> Float {
    return Float(bitrate) / 1_000_000
}

func bitrateFromMbps(bitrate: Float) -> UInt32 {
    return UInt32(bitrate * 1_000_000)
}

func radiansToDegrees(_ number: Double) -> Int {
    return Int(number * 180 / .pi)
}

func diffAngles(_ one: Double, _ two: Double) -> Int {
    let diff = abs(radiansToDegrees(one - two))
    return min(diff, 360 - diff)
}

extension URLResponse {
    var http: HTTPURLResponse? {
        return self as? HTTPURLResponse
    }
}

extension HTTPURLResponse {
    var isSuccessful: Bool {
        return 200 ... 299 ~= statusCode
    }

    var isNotFound: Bool {
        return statusCode == 404
    }

    var isUnauthorized: Bool {
        return statusCode == 401
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

let smallFont = Font.system(size: 13)

extension UInt64 {
    func formatBytes() -> String {
        return sizeFormatter.string(fromByteCount: Int64(self))
    }
}

extension ProcessInfo.ThermalState {
    func color() -> Color {
        switch self {
        case .nominal:
            return .white
        case .fair:
            return .white
        case .serious:
            return .yellow
        case .critical:
            return .red
        default:
            return .pink
        }
    }
}

func yesOrNo(_ value: Bool) -> String {
    if value {
        return "Yes"
    } else {
        return "No"
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
        return ((self >> index) & 1) == 1
    }
}

extension Data {
    func hexString() -> String {
        return map { String(format: "%02hhx", $0) }.joined()
    }

    func getInt64Be(offset: Int = 0) -> Int64 {
        return Int64(UInt64(getFourBytesBe(offset: offset)) << 32 | UInt64(getFourBytesBe(offset: offset + 4)))
    }

    func getUInt32Be(offset: Int = 0) -> UInt32 {
        return withUnsafeBytes { data in
            data.load(fromByteOffset: offset, as: UInt32.self)
        }.bigEndian
    }

    func getUInt16Be(offset: Int = 0) -> UInt16 {
        return withUnsafeBytes { data in
            data.load(fromByteOffset: offset, as: UInt16.self)
        }.bigEndian
    }

    func getThreeBytesBe(offset: Int = 0) -> UInt32 {
        return UInt32(self[offset]) << 16 | UInt32(self[offset + 1]) << 8 | UInt32(self[offset + 2])
    }

    func getFourBytesBe(offset: Int = 0) -> UInt32 {
        return UInt32(self[offset]) << 24 | UInt32(self[offset + 1]) << 16 | UInt32(self[offset + 2]) <<
            8 |
            UInt32(self[offset + 3])
    }

    func getFourBytesLe(offset: Int = 0) -> UInt32 {
        return UInt32(self[offset + 3]) << 24 | UInt32(self[offset + 2]) << 16 |
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
            ) == noErr else {
                return nil
            }
            guard let blockBuffer else {
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
private let cameraPositionMediaPlayer = "(Media player)"

func rtmpCamera(name: String) -> String {
    return "\(name) \(cameraPositionRtmp)"
}

func isRtmpCamera(camera: String) -> Bool {
    return camera.hasSuffix(cameraPositionRtmp)
}

func srtlaCamera(name: String) -> String {
    return "\(name) \(cameraPositionSrtla)"
}

func isSrtlaCamera(camera: String) -> Bool {
    return camera.hasSuffix(cameraPositionSrtla)
}

func mediaPlayerCamera(name: String) -> String {
    return "\(name) \(cameraPositionMediaPlayer)"
}

func isMediaPlayerCamera(camera: String) -> Bool {
    return camera.hasSuffix(cameraPositionMediaPlayer)
}

func formatAudioLevelDb(level: Float) -> String {
    return String(localized: "\(Int(level)) dB,")
}

func formatAudioLevel(level: Float) -> String {
    if level.isNaN {
        return "Muted,"
    } else if level == .infinity {
        return "Unknown,"
    } else {
        return formatAudioLevelDb(level: level)
    }
}

func formatAudioLevelChannels(channels: Int) -> String {
    return String(localized: " \(channels) ch")
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
    var milliseconds: Int64 {
        return components.seconds * 1000 + components.attoseconds / 1_000_000_000_000_000
    }

    var seconds: Double {
        return Double(milliseconds) / 1000
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
        return Data(utf8)
    }
}

class RgbColor: Codable, Equatable {
    static func == (lhs: RgbColor, rhs: RgbColor) -> Bool {
        return lhs.red == rhs.red && lhs.green == rhs.green && lhs.blue == rhs.blue && lhs.opacity == rhs
            .opacity
    }

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
        guard red < threshold && green < threshold && blue < threshold else {
            return self
        }
        return .init(red: red + threshold, green: green + threshold, blue: blue + threshold)
    }

    static func fromHex(string: String) -> RgbColor? {
        if let colorNumber = Int(string.suffix(6), radix: 16) {
            return RgbColor(
                red: (colorNumber >> 16) & 0xFF,
                green: (colorNumber >> 8) & 0xFF,
                blue: colorNumber & 0xFF
            )
        } else {
            return nil
        }
    }
}

extension RgbColor {
    private func colorScale(_ color: Int) -> Double {
        return Double(color) / 255
    }

    func color() -> Color {
        return Color(
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
    if first == 6 && second <= 4 {
        return true
    }
    return false
}

extension KeyedEncodingContainer {
    mutating func encode<T>(_ key: KeyedEncodingContainer<K>.Key, _ value: T) throws where T: Encodable {
        try encode(value, forKey: key)
    }
}

extension KeyedDecodingContainer {
    func decode<T>(_ key: KeyedDecodingContainer<K>.Key, _ type: T.Type, _ defaultValue: T) -> T where T: Decodable {
        return (try? decode(type, forKey: key)) ?? defaultValue
    }
}
