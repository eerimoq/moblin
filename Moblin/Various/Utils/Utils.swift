import AVFoundation
import SwiftUI

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

func openUrl(url: String) {
    return UIApplication.shared.open(URL(string: url)!)
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

func currentPresentationTimeStamp() -> CMTime {
    return CMClockGetTime(CMClockGetHostTimeClock())
}

func utcTimeDeltaFromNow(to: Double) -> Double {
    return Date(timeIntervalSince1970: to).timeIntervalSinceNow
}

func emojiFlag(countryCode: String?) -> String {
    guard let countryCode else {
        return ""
    }
    let base: UInt32 = 127_397
    var emote = ""
    for ch in countryCode.unicodeScalars {
        emote.unicodeScalars.append(UnicodeScalar(base + ch.value)!)
    }
    return emote
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
    request.setContentType("multipart/form-data; boundary=\(boundary)")
    var data = Data()
    if let message {
        data.append("\r\n--\(boundary)\r\n".utf8Data)
        data.append("content-disposition: form-data; name=\"content\"\r\n\r\n".utf8Data)
        data.append(message.utf8Data)
    }
    data.append("\r\n--\(boundary)\r\n".utf8Data)
    data.append(
        "content-disposition: form-data; name=\"\(paramName)\"; filename=\"\(fileName)\"\r\n".utf8Data
    )
    data.append("content-type: image/jpeg\r\n\r\n".utf8Data)
    data.append(image)
    data.append("\r\n--\(boundary)--\r\n".utf8Data)
    httpCall(request: request, body: data) { data in
        onCompleted(data != nil)
    }
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

func formatMinutes(minutes: Int) -> String {
    let suffix: String
    if minutes == 1 {
        suffix = String(localized: "minute")
    } else {
        suffix = String(localized: "minutes")
    }
    return "\(minutes) \(suffix)"
}

extension CGSize {
    func minimum() -> CGFloat {
        return min(height, width)
    }

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
    private var memoryUsage: UInt64 = 0

    func update(now: ContinuousClock.Instant) {
        updateCpuUsage(now: now)
        updateMemoryUsage()
    }

    func getCpuUsage() -> Int {
        return Int(cpuUsage)
    }

    func getMemoryUsage() -> Int {
        return Int(memoryUsage)
    }

    private func updateCpuUsage(now: ContinuousClock.Instant) {
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

    private func updateMemoryUsage() {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let kerr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        if kerr == KERN_SUCCESS {
            memoryUsage = info.phys_footprint / 1024 / 1024
        } else {
            memoryUsage = 0
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

extension Data {
    static func random(length: Int) -> Data {
        return Data((0 ..< length).map { _ in UInt8.random(in: UInt8.min ... UInt8.max) })
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
    func name() -> String {
        return NSLocale.current.localizedString(forIdentifier: minimalIdentifier) ?? "Unknown"
    }
}

extension AVAsset {
    func duration() -> Double {
        let semaphore = DispatchSemaphore(value: 0)
        var duration: Double?
        Task {
            duration = try? await load(.duration).seconds
            semaphore.signal()
        }
        semaphore.wait()
        return duration ?? 0
    }
}
