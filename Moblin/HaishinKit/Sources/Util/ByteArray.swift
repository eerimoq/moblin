import Foundation

protocol ByteArrayConvertible {
    var data: Data { get }
    var length: Int { get set }
    var position: Int { get set }
    var bytesAvailable: Int { get }

    @discardableResult
    func writeUInt8(_ value: UInt8) -> Self
    func readUInt8() throws -> UInt8

    @discardableResult
    func writeUInt16(_ value: UInt16) -> Self

    @discardableResult
    func writeUInt32(_ value: UInt32) -> Self
    func readUInt32() throws -> UInt32

    func readUTF8() throws -> String

    @discardableResult
    func writeUTF8Bytes(_ value: String) -> Self

    @discardableResult
    func writeBytes(_ value: Data) -> Self
    func readBytes(_ length: Int) throws -> Data

    @discardableResult
    func clear() -> Self
}

/**
 * The ByteArray class provides methods and properties the reading or writing with binary data.
 */
open class ByteArray: ByteArrayConvertible {
    static let fillZero: [UInt8] = [0x00]

    static let sizeOfInt8: Int = 1
    static let sizeOfInt16: Int = 2
    static let sizeOfInt24: Int = 3
    static let sizeOfInt32: Int = 4
    static let sizeOfDouble: Int = 8

    /**
     * The ByteArray error domain codes.
     */
    public enum Error: Swift.Error {
        /// Error cause end of data.
        case eof
        /// Failed to parse
        case parse
    }

    /// Creates an empty ByteArray.
    public init() {}

    /// Creates a ByteArray with data.
    public init(data: Data) {
        self.data = data
    }

    private(set) var data = Data()

    /// Specifies the length of buffer.
    public var length: Int {
        get {
            data.count
        }
        set {
            switch true {
            case data.count < newValue:
                data.append(Data(count: newValue - data.count))
            case newValue < data.count:
                data = data.subdata(in: 0 ..< newValue)
            default:
                break
            }
        }
    }

    /// Specifies the position of buffer.
    public var position: Int = 0

    /// The bytesAvalibale or not.
    public var bytesAvailable: Int {
        data.count - position
    }

    public subscript(i: Int) -> UInt8 {
        get {
            data[i]
        }
        set {
            data[i] = newValue
        }
    }

    /// Reading an UInt8 value.
    public func readUInt8() throws -> UInt8 {
        guard ByteArray.sizeOfInt8 <= bytesAvailable else {
            throw ByteArray.Error.eof
        }
        defer {
            position += 1
        }
        return data[position]
    }

    /// Writing an UInt8 value.
    @discardableResult
    public func writeUInt8(_ value: UInt8) -> Self {
        writeBytes(value.data)
    }

    /// Readning an UInt16 value.
    public func readUInt16() throws -> UInt16 {
        guard ByteArray.sizeOfInt16 <= bytesAvailable else {
            throw ByteArray.Error.eof
        }
        position += ByteArray.sizeOfInt16
        return UInt16(data: data[position - ByteArray.sizeOfInt16 ..< position]).bigEndian
    }

    /// Writing an UInt16 value.
    @discardableResult
    public func writeUInt16(_ value: UInt16) -> Self {
        writeBytes(value.bigEndian.data)
    }

    /// Reading an UInt24 value.
    public func readUInt24() throws -> UInt32 {
        guard ByteArray.sizeOfInt24 <= bytesAvailable else {
            throw ByteArray.Error.eof
        }
        position += ByteArray.sizeOfInt24
        return UInt32(data: ByteArray.fillZero + data[position - ByteArray.sizeOfInt24 ..< position])
            .bigEndian
    }

    /// Reading an UInt32 value.
    public func readUInt32() throws -> UInt32 {
        guard ByteArray.sizeOfInt32 <= bytesAvailable else {
            throw ByteArray.Error.eof
        }
        position += ByteArray.sizeOfInt32
        return UInt32(data: data[position - ByteArray.sizeOfInt32 ..< position]).bigEndian
    }

    /// Writing an UInt32 value.
    @discardableResult
    public func writeUInt32(_ value: UInt32) -> Self {
        writeBytes(value.bigEndian.data)
    }

    /// Writing an Int32 value.
    @discardableResult
    public func writeInt32(_ value: Int32) -> Self {
        writeBytes(value.bigEndian.data)
    }

    public func readDouble() throws -> Double {
        guard ByteArray.sizeOfDouble <= bytesAvailable else {
            throw ByteArray.Error.eof
        }
        position += ByteArray.sizeOfDouble
        return Double(data: Data(data.subdata(in: position - ByteArray.sizeOfDouble ..< position).reversed()))
    }

    @discardableResult
    public func writeDouble(_ value: Double) -> Self {
        writeBytes(Data(value.data.reversed()))
    }

    public func readUTF8() throws -> String {
        try readUTF8Bytes(Int(readUInt16()))
    }

    @discardableResult
    public func clear() -> Self {
        position = 0
        data.removeAll()
        return self
    }

    func readUTF8Bytes(_ length: Int) throws -> String {
        guard length <= bytesAvailable else {
            throw ByteArray.Error.eof
        }
        position += length
        guard let result = String(data: data.subdata(in: position - length ..< position), encoding: .utf8)
        else {
            throw ByteArray.Error.parse
        }
        return result
    }

    @discardableResult
    func writeUTF8Bytes(_ value: String) -> Self {
        writeBytes(Data(value.utf8))
    }

    func readBytes(_ length: Int) throws -> Data {
        guard length <= bytesAvailable else {
            throw ByteArray.Error.eof
        }
        position += length
        return data.subdata(in: position - length ..< position)
    }

    @discardableResult
    func writeBytes(_ value: Data) -> Self {
        if position == data.count {
            data.append(value)
            position = data.count
            return self
        }
        let length: Int = min(data.count, value.count)
        data[position ..< position + length] = value[0 ..< length]
        if length == data.count {
            data.append(value[length ..< value.count])
        }
        position += value.count
        return self
    }

    func sequence(_ length: Int, lambda: (ByteArray) -> Void) {
        let r: Int = (data.count - position) % length
        for index in stride(
            from: data.startIndex.advanced(by: position),
            to: data.endIndex.advanced(by: -r),
            by: length
        ) {
            lambda(ByteArray(data: data.subdata(in: index ..< index.advanced(by: length))))
        }
        if r > 0 {
            lambda(ByteArray(data: data.advanced(by: data.endIndex - r)))
        }
    }

    func toUInt32() -> [UInt32] {
        let size: Int = MemoryLayout<UInt32>.size
        if (data.endIndex - position) % size != 0 {
            return []
        }
        var result: [UInt32] = []
        for index in stride(from: data.startIndex.advanced(by: position), to: data.endIndex, by: size) {
            result.append(UInt32(data: data[index ..< index.advanced(by: size)]))
        }
        return result
    }
}
