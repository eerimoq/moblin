import Foundation

/// Atomic<T> class
/// - seealso: https://www.objc.io/blog/2018/12/18/atomic-variables/
struct Atomic<A> {
    private let queue = DispatchQueue(label: "com.haishinkit.HaishinKit.Atomic")
    private var _value: A

    var value: A {
        queue.sync { self._value }
    }

    init(_ value: A) {
        _value = value
    }

    mutating func mutate(_ transform: (inout A) -> Void) {
        queue.sync {
            transform(&self._value)
        }
    }
}
