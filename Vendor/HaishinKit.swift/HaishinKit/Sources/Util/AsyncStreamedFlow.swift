import Foundation

@propertyWrapper
package struct AsyncStreamedFlow<T: Sendable> {
    package var wrappedValue: AsyncStream<T> {
        mutating get {
            let (stream, continuation) = AsyncStream.makeStream(of: T.self, bufferingPolicy: bufferingPolicy)
            self.continuation = continuation
            return stream
        }
        @available(*, unavailable)
        set { _ = newValue }
    }
    private let bufferingPolicy: AsyncStream<T>.Continuation.BufferingPolicy
    private var continuation: AsyncStream<T>.Continuation? {
        didSet {
            oldValue?.finish()
        }
    }

    package init(_ bufferingPolicy: AsyncStream<T>.Continuation.BufferingPolicy = .unbounded) {
        self.bufferingPolicy = bufferingPolicy
    }

    package func yield(_ value: T) {
        continuation?.yield(value)
    }

    package mutating func finish() {
        continuation = nil
    }
}
