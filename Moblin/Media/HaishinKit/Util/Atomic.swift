import os

struct Atomic<A: Sendable> {
    private let lock: OSAllocatedUnfairLock<A>

    var value: A {
        lock.withLock { $0 }
    }

    init(_ value: A) {
        lock = OSAllocatedUnfairLock(initialState: value)
    }

    @discardableResult
    func mutate<R: Sendable>(_ transform: @Sendable (inout A) -> R) -> R {
        lock.withLock {
            transform(&$0)
        }
    }
}
