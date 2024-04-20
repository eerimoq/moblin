import Foundation

extension ExpressibleByIntegerLiteral {
    var data: Data {
        var value: Self = self
        return Data(bytes: &value, count: MemoryLayout<Self>.size)
    }

    init(data: Slice<Data>) {
        self.init(data: Data(data))
    }
}
