import Foundation

extension ExpressibleByIntegerLiteral {
    var data: Data {
        var value: Self = self
        return Data(bytes: &value, count: MemoryLayout<Self>.size)
    }
}
