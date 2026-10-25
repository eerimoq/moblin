import Foundation
@testable import Moblin

private final class BundleToken {}

func isEqual<T: FloatingPoint>(_ actual: T, _ expected: T, epsilon: T) -> Bool {
    abs(actual - expected) < epsilon
}

func areEqual<T: FloatingPoint>(_ actual: [T], _ expected: [T], epsilon: T) -> Bool {
    guard actual.count == expected.count else {
        return false
    }
    for index in 0 ..< actual.count where !isEqual(actual[index], expected[index], epsilon: epsilon) {
        return false
    }
    return true
}

final class MessageQueue<Message: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer: [Message] = []
    private var continuations: [CheckedContinuation<Message, Never>] = []

    func put(_ message: Message) {
        lock.lock()
        let continuation = continuations.isEmpty ? nil : continuations.removeFirst()
        if continuation == nil {
            buffer.append(message)
        }
        lock.unlock()
        continuation?.resume(returning: message)
    }

    func get() async -> Message {
        await withCheckedContinuation { continuation in
            lock.lock()
            if buffer.isEmpty {
                continuations.append(continuation)
                lock.unlock()
            } else {
                let message = buffer.removeFirst()
                lock.unlock()
                continuation.resume(returning: message)
            }
        }
    }
}

func waitUntil(timeout: Duration, _ condition: () -> Bool) -> Bool {
    let startTime = ContinuousClock.now
    while !condition() {
        if startTime.duration(to: .now) > timeout {
            return false
        }
        Thread.sleep(forTimeInterval: 0.02)
    }
    return true
}

struct TemporaryDirectory: ~Copyable {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory.appending(component: UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        url.remove()
    }
}

func readMainFile(name: String, suffix: String) throws -> Data {
    let url = Bundle.main.url(forResource: name, withExtension: suffix)!
    return try Data(contentsOf: url)
}

func readTestFile(name: String, suffix: String) throws -> Data {
    let url = Bundle(for: BundleToken.self).url(forResource: name, withExtension: suffix)!
    return try Data(contentsOf: url)
}

func makeEmotes(_ names: [String]) -> Emotes {
    let emotes = Emotes()
    var byName: [String: Emote] = [:]
    for name in names {
        byName[name] = Emote(url: URL(string: "https://emotes.example.com/\(name)")!)
    }
    emotes.addEmotes(byName)
    return emotes
}

func texts(_ segments: [ChatPostSegment]) -> [String?] {
    segments.map(\.text)
}

func emoteNames(_ segments: [ChatPostSegment]) -> [String?] {
    segments.map { $0.url?.still?.lastPathComponent }
}

func spokenEmoteNames(_ segments: [ChatPostSegment]) -> [String?] {
    segments.map { ($0.url ?? $0.bigGifUrl)?.name }
}
