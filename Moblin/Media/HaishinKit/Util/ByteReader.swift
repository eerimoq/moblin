import Foundation

class ByteReader {
    static let sizeOfInt8 = 1
    static let sizeOfDouble = 8

    private enum Error: Swift.Error {
        case eof
        case parse
    }

    private(set) var data: Data
    var position = 0

    var bytesAvailable: Int {
        data.count - position
    }

    init(data: Data) {
        self.data = data
    }

    func readUInt8() throws -> UInt8 {
        guard bytesAvailable >= ByteReader.sizeOfInt8 else {
            throw ByteReader.Error.eof
        }
        defer {
            position += 1
        }
        return data[position]
    }

    func readUInt16() throws -> UInt16 {
        guard bytesAvailable >= 2 else {
            throw ByteReader.Error.eof
        }
        defer {
            position += 2
        }
        return data.withUnsafeBytes { pointer in
            pointer.readUInt16(offset: position)
        }
    }

    func readUInt16Le() throws -> UInt16 {
        return try UInt16(readUInt8()) | (UInt16(readUInt8()) << 8)
    }

    func readUInt24() throws -> UInt32 {
        return try (UInt32(readUInt8()) << 16) | (UInt32(readUInt8()) << 8) | UInt32(readUInt8())
    }

    func readUInt24Le() throws -> UInt32 {
        return try UInt32(readUInt8()) | (UInt32(readUInt8()) << 8) | (UInt32(readUInt8()) << 16)
    }

    func readUInt32() throws -> UInt32 {
        guard bytesAvailable >= 4 else {
            throw ByteReader.Error.eof
        }
        defer {
            position += 4
        }
        return data.withUnsafeBytes { pointer in
            pointer.readUInt32(offset: position)
        }
    }

    func readUInt32Le() throws -> UInt32 {
        return try UInt32(readUInt8()) | (UInt32(readUInt8()) << 8) | (UInt32(readUInt8()) << 16) |
            (UInt32(readUInt8()) << 24)
    }

    func readDouble() throws -> Double {
        guard bytesAvailable >= ByteReader.sizeOfDouble else {
            throw ByteReader.Error.eof
        }
        position += ByteReader.sizeOfDouble
        return Double(data: Data(data.subdata(in: position - ByteReader.sizeOfDouble ..< position).reversed()))
    }

    func readUTF8Bytes(_ length: Int) throws -> String {
        guard bytesAvailable >= length else {
            throw ByteReader.Error.eof
        }
        position += length
        guard let result = String(data: data.subdata(in: position - length ..< position), encoding: .utf8)
        else {
            throw ByteReader.Error.parse
        }
        return result
    }

    func readBytes(_ length: Int) throws -> Data {
        guard length >= 0, bytesAvailable >= length else {
            throw ByteReader.Error.eof
        }
        position += length
        return data.subdata(in: position - length ..< position)
    }

    func skipBytes(_ length: Int) throws {
        guard length >= 0, bytesAvailable >= length else {
            throw ByteReader.Error.eof
        }
        position += length
    }
}
