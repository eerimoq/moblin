func isEqual<T: FloatingPoint>(_ actual: T, _ expected: T, epsilon: T) -> Bool {
    return abs(actual - expected) < epsilon
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
            return message
        } else {
            return await withCheckedContinuation {
                continuations.append($0)
            }
        }
    }
}
