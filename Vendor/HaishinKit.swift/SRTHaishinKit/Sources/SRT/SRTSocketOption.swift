import Foundation
import libsrt

/// A structure that represents a Key-Value-Object for the SRTSocket.
public struct SRTSocketOption: Sendable {
    /// The error domain codes.
    public enum Error: Swift.Error {
        case invalidOption(_ message: String)
        case invalidArgument(_ message: String)
    }

    private static let trueStringLiterals: [String: Bool] = [
        "1": true,
        "on": true,
        "yes": true,
        "true": true
    ]

    private static let falseStringLiterals: [String: Bool] = [
        "0": false,
        "off": false,
        "no": false,
        "false": false
    ]

    /// Constants that indicate the sockopt c-types.
    public enum CType: Int, Sendable {
        case string
        case int32
        case int64
        case bool

        var size: Int {
            switch self {
            case .string:
                return 512
            case .int32:
                return MemoryLayout<Int32>.size
            case .int64:
                return MemoryLayout<Int64>.size
            case .bool:
                return MemoryLayout<Bool>.size
            }
        }

        func data(_ value: any Sendable) throws -> Data {
            switch self {
            case .string:
                guard let data = String(describing: value).data(using: .utf8) else {
                    throw Error.invalidArgument("\(value)")
                }
                return data
            case .bool:
                guard var value = value as? Bool else {
                    throw Error.invalidArgument("\(value)")
                }
                return .init(bytes: &value, count: size)
            case .int32:
                guard var value = value as? Int32 else {
                    throw Error.invalidArgument("\(value)")
                }
                return .init(bytes: &value, count: size)
            case .int64:
                guard var value = value as? Int64 else {
                    throw Error.invalidArgument("\(value)")
                }
                return .init(bytes: &value, count: size)
            }
        }
    }

    /// Constants that indicate the sockopt binding timings.
    public enum Restriction: Int, Sendable {
        case preBind
        case pre
        case post
    }

    /// A structure that defines the name of a SRTSocket option.
    public struct Name: Sendable {
        public typealias RawValue = String

        public let rawValue: String
        let symbol: SRT_SOCKOPT
        let restriction: Restriction?
        let type: CType

        public init(rawValue: String, symbol: SRT_SOCKOPT, restriction: Restriction?, type: CType) {
            self.rawValue = rawValue
            self.symbol = symbol
            self.restriction = restriction
            self.type = type
        }
    }

    /// The socket option's name.
    public let name: Name

    /// The socket option's value expressed as a String value.
    public var stringValue: String {
        switch name.type {
        case .string:
            return String(data: data, encoding: .utf8) ?? ""
        case .int32:
            return data.withUnsafeBytes { $0.load(as: Int32.self) }.description
        case .int64:
            return data.withUnsafeBytes { $0.load(as: Int64.self) }.description
        case .bool:
            return (data[0] == 1).description
        }
    }

    /// The socket option's value expressed as a Int value.
    public var intValue: Int {
        switch name.type {
        case .string:
            return -1
        case .int32:
            return Int(data.withUnsafeBytes { $0.load(as: Int32.self) })
        case .int64:
            return Int(data.withUnsafeBytes { $0.load(as: Int64.self) })
        case .bool:
            return Int(data[0])
        }
    }

    /// The socket option's value expressed as a Boolean value.
    public var boolValue: Bool {
        switch name.type {
        case .string:
            return false
        case .int32:
            return Int(data.withUnsafeBytes { $0.load(as: Int32.self) }) == 1
        case .int64:
            return Int(data.withUnsafeBytes { $0.load(as: Int64.self) }) == 1
        case .bool:
            return data[0] == 1
        }
    }

    private let data: Data

    /// Creates an option.
    public init(name: Name, value: String) throws {
        self.name = name
        switch name.type {
        case .string:
            self.data = try name.type.data(value)
        case .int32:
            switch name.rawValue {
            case "transtype":
                switch value {
                case "live":
                    self.data = try name.type.data(Int32(SRTT_LIVE.rawValue))
                case "file":
                    self.data = try name.type.data(Int32(SRTT_FILE.rawValue))
                default:
                    throw Error.invalidOption(name.rawValue)
                }
            default:
                self.data = try name.type.data(Int32(value))
            }
        case .int64:
            self.data = try name.type.data(Int64(value))
        case .bool:
            let key = String(describing: value).lowercased()
            if let bool = Self.trueStringLiterals[key] {
                self.data = try name.type.data(bool)
            } else if let bool = Self.falseStringLiterals[key] {
                self.data = try name.type.data(bool)
            } else {
                throw Error.invalidOption(name.rawValue)
            }
        }
    }

    /// Creates an option.
    public init(name: Name, value: Int) throws {
        self.name = name
        switch name.type {
        case .string:
            self.data = try name.type.data(value.description)
        case .int32:
            self.data = try name.type.data(Int32(value))
        case .int64:
            self.data = try name.type.data(Int64(value))
        case .bool:
            self.data = try name.type.data(value == 1)
        }
    }

    init(name: Name, socket: SRTSOCKET) throws {
        self.name = name
        var data = Data(repeating: 0, count: name.type.size)
        var length = Int32(name.type.size)
        let result: Int32 = data.withUnsafeMutableBytes {
            guard let buffer = $0.baseAddress else {
                return -1
            }
            return srt_getsockflag(socket, name.symbol, buffer, &length)
        }
        if result < 0 {
            throw Error.invalidOption(String(cString: srt_getlasterror_str()))
        }
        self.data = data.subdata(in: 0..<Data.Index(length))
    }

    func setSockflag(_ socket: SRTSOCKET) throws {
        let result: Int32 = data.withUnsafeBytes { pointer in
            guard let buffer = pointer.baseAddress else {
                return -1
            }
            return srt_setsockflag(socket, name.symbol, buffer, Int32(data.count))
        }
        if result < 0 {
            throw Error.invalidOption(String(cString: srt_getlasterror_str()))
        }
    }
}
