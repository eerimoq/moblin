import Foundation

@dynamicMemberLookup
struct RTPFormatParameter: Sendable {
    static let empty = RTPFormatParameter()

    private let data: [String: String]

    subscript(dynamicMember key: String) -> Int? {
        guard let value = data[key] else {
            return nil
        }
        return Int(value)
    }

    subscript(dynamicMember key: String) -> Bool {
        guard let value = data[key] else {
            return false
        }
        return value == "1" || value == "true"
    }
}

extension RTPFormatParameter {
    init() {
        self.data = [:]
    }

    init(_ value: String) {
        var data: [String: String] = [:]
        let pairs = value.split(separator: ";")
        for pair in pairs {
            let parts = pair.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2 {
                data[parts[0]] = parts[1]
            }
        }
        self.data = data
    }
}
