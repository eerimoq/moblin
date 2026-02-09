import Foundation

extension Array where Element == String {
    func withCStrings<R>(_ body: ([UnsafePointer<CChar>]) -> R) -> R {
        var cStringPtrs: [UnsafePointer<CChar>] = []
        cStringPtrs.reserveCapacity(count)
        func loop(_ i: Int, _ current: [UnsafePointer<CChar>], _ body: ([UnsafePointer<CChar>]) -> R) -> R {
            if i == count {
                return body(current)
            }
            return self[i].withCString { cstr in
                var next = current
                next.append(cstr)
                return loop(i + 1, next, body)
            }
        }
        return loop(0, [], body)
    }

    func withCStringArray<R>(_ body: (UnsafeMutablePointer<UnsafePointer<CChar>?>) -> R) -> R {
        let cStrings = self.map { $0.utf8CString }
        let pointerArray = UnsafeMutablePointer<UnsafePointer<CChar>?>.allocate(capacity: cStrings.count)
        for (i, cString) in cStrings.enumerated() {
            cString.withUnsafeBufferPointer { buf in
                pointerArray[i] = buf.baseAddress
            }
        }
        let result = body(pointerArray)
        pointerArray.deallocate()
        return result
    }
}
