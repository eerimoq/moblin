import Foundation

class ByteArray {
    static let sizeOfInt8 = 1
    static let sizeOfDouble = 8

    enum Error: Swift.Error {
        case eof
        case parse
    }

    init() {}

    init(data: Data) {
        self.data = data
    }

    private(set) var data = Data()

    var length: Int {
        get {
            data.count
        }
        set {
            if newValue > data.count {
                data.append(Data(count: newValue - data.count))
            } else if newValue < data.count {
                data = data.subdata(in: 0 ..< newValue)
            }
        }
    }

    var position = 0

    var bytesAvailable: Int {
        data.count - position
    }

    subscript(i: Int) -> UInt8 {
        get {
            data[i]
        }
        set {
            data[i] = newValue
        }
    }

    func readUInt8() throws -> UInt8 {
        guard bytesAvailable >= ByteArray.sizeOfInt8 else {
            throw ByteArray.Error.eof
        }
        defer {
            position += 1
        }
        return data[position]
    }

    @discardableResult
    func writeUInt8(_ value: UInt8) -> Self {
        writeBytes(value.data)
    }

    func readUInt16() throws -> UInt16 {
        return try (UInt16(readUInt8()) << 8) | UInt16(readUInt8())
    }

    @discardableResult
    func writeUInt16(_ value: UInt16) -> Self {
        writeBytes(value.bigEndian.data)
    }

    func readUInt16Le() throws -> UInt16 {
        return try UInt16(readUInt8()) | (UInt16(readUInt8()) << 8)
    }

    @discardableResult
    func writeUInt16Le(_ value: UInt16) -> Self {
        writeUInt8(UInt8(value & 0xFF))
        return writeUInt8(UInt8((value >> 8) & 0xFF))
    }

    func readUInt24() throws -> UInt32 {
        return try (UInt32(readUInt8()) << 16) | (UInt32(readUInt8()) << 8) | UInt32(readUInt8())
    }

    func readUInt24Le() throws -> UInt32 {
        return try UInt32(readUInt8()) | (UInt32(readUInt8()) << 8) | (UInt32(readUInt8()) << 16)
    }

    @discardableResult
    func writeUInt24(_ value: UInt32) -> Self {
        writeUInt8(UInt8((value >> 16) & 0xFF))
        writeUInt8(UInt8((value >> 8) & 0xFF))
        return writeUInt8(UInt8(value & 0xFF))
    }

    @discardableResult
    func writeUInt24Le(_ value: UInt32) -> Self {
        writeUInt8(UInt8(value & 0xFF))
        writeUInt8(UInt8((value >> 8) & 0xFF))
        return writeUInt8(UInt8((value >> 16) & 0xFF))
    }

    func readUInt32() throws -> UInt32 {
        return try (UInt32(readUInt8()) << 24) | (UInt32(readUInt8()) << 16) | (UInt32(readUInt8()) << 8) |
            UInt32(readUInt8())
    }

    func readUInt32Le() throws -> UInt32 {
        return try UInt32(readUInt8()) | (UInt32(readUInt8()) << 8) | (UInt32(readUInt8()) << 16) |
            (UInt32(readUInt8()) << 24)
    }

    @discardableResult
    func writeUInt32(_ value: UInt32) -> Self {
        writeBytes(value.bigEndian.data)
    }

    @discardableResult
    func writeUInt32Le(_ value: UInt32) -> Self {
        writeUInt8(UInt8(value & 0xFF))
        writeUInt8(UInt8((value >> 8) & 0xFF))
        writeUInt8(UInt8((value >> 16) & 0xFF))
        return writeUInt8(UInt8((value >> 24) & 0xFF))
    }

    @discardableResult
    func writeInt32(_ value: Int32) -> Self {
        writeBytes(value.bigEndian.data)
    }

    func readDouble() throws -> Double {
        guard bytesAvailable >= ByteArray.sizeOfDouble else {
            throw ByteArray.Error.eof
        }
        position += ByteArray.sizeOfDouble
        return Double(data: Data(data.subdata(in: position - ByteArray.sizeOfDouble ..< position).reversed()))
    }

    @discardableResult
    func writeDouble(_ value: Double) -> Self {
        writeBytes(Data(value.data.reversed()))
    }

    @discardableResult
    func clear() -> Self {
        position = 0
        data.removeAll()
        return self
    }

    func readUTF8Bytes(_ length: Int) throws -> String {
        guard bytesAvailable >= length else {
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
        guard bytesAvailable >= length else {
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
        let length = min(data.count, value.count)
        data[position ..< position + length] = value[0 ..< length]
        if length == data.count {
            data.append(value[length ..< value.count])
        }
        position += value.count
        return self
    }

    func sequence(_ length: Int, lambda: (ByteArray) -> Void) {
        let r = (data.count - position) % length
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
        let size = MemoryLayout<UInt32>.size
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
