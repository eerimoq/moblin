import os

struct Atomic<A: Sendable> {
    private let lock: OSAllocatedUnfairLock<A>

    var value: A {
        lock.withLock { $0 }
    }

    init(_ value: A) {
        lock = OSAllocatedUnfairLock(initialState: value)
    }

    func mutate(_ transform: @Sendable (inout A) -> Void) {
        lock.withLock {
            transform(&$0)
        }
    }
}
