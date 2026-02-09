public enum RTCError: RawRepresentable, Swift.Error {
    @discardableResult
    static func check(_ result: Int32) throws -> Int32 {
        if result < 0 {
            throw RTCError(rawValue: result)
        }
        return result
    }

    public typealias RawValue = Int32

    case invalid
    case failure
    case notAvail
    case tooSmall
    case undefined(value: Int32)

    public var rawValue: Int32 {
        switch self {
        case .invalid:
            return -1
        case .failure:
            return -2
        case .notAvail:
            return -3
        case .tooSmall:
            return -4
        case .undefined(let value):
            return value
        }
    }

    public init(rawValue: Int32) {
        switch rawValue {
        case -1:
            self = .invalid
        case -2:
            self = .failure
        case -3:
            self = .notAvail
        case -4:
            self = .tooSmall
        default:
            self = .undefined(value: rawValue)
        }
    }
}
