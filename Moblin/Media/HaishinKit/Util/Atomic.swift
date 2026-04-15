import os

struct Atomic<A: Sendable> {
    private let lock: OSAllocatedUnfairLock<A>

    var value: A {
        lock.withLock { $0 }
    }

    init(_ value: A) {
        lock = OSAllocatedUnfairLock(initialState: value)
    }

    func mutate(_ transform: (inout A) -> Void) {
        lock.withLock { state in
            transform(&state)
        }
    }
}
