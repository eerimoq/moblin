import Foundation

extension ExpressibleByIntegerLiteral {
    var data: Data {
        var value = self
        return withUnsafeBytes(of: &value) { Data($0) }
    }
}
