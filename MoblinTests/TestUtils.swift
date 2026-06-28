import Foundation

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

class MessageQueue<Message> {
    private var buffer: [Message] = []
    private var continuations: [CheckedContinuation<Message, Never>] = []

    func put(_ message: Message) {
        if let continuation = continuations.popLast() {
            continuation.resume(returning: message)
        } else {
            buffer.append(message)
        }
    }

    func get() async -> Message {
        if let message = buffer.popLast() {
            message
        } else {
            await withCheckedContinuation {
                continuations.append($0)
            }
        }
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
