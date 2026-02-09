import Foundation

@propertyWrapper
package struct AsyncStreamed<T: Sendable & Equatable> {
    package var wrappedValue: AsyncStream<T> {
        get {
            defer {
                continuation.yield(value)
            }
            return stream
        }
        @available(*, unavailable)
        set { _ = newValue }
    }
    package var value: T {
        didSet {
            guard value != oldValue else {
                return
            }
            continuation.yield(value)
        }
    }
    private let stream: AsyncStream<T>
    private let continuation: AsyncStream<T>.Continuation

    package init(_ value: T, bufferingPolicy limit: AsyncStream<T>.Continuation.BufferingPolicy = .unbounded) {
        let (stream, continuation) = AsyncStream.makeStream(of: T.self, bufferingPolicy: limit)
        self.value = value
        self.stream = stream
        self.continuation = continuation
    }
}
