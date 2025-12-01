import Foundation

enum AmfError: Error {
    case decode
    case arrayTooBig
    case notObjectEnd
}

enum Amf0Type: UInt8 {
    case number = 0x00
    case bool = 0x01
    case string = 0x02
    case object = 0x03
    case null = 0x05
    case undefined = 0x06
    case reference = 0x07
    case ecmaArray = 0x08
    case objectEnd = 0x09
    case strictArray = 0x0A
    case date = 0x0B
    case longString = 0x0C
    case unsupported = 0x0D
    case xmlDocument = 0x0F
    case typedObject = 0x10
    case avmplush = 0x11
}

final class Amf0Encoder: ByteWriter {
    func encode(_ value: Any?) {
        switch value {
        case let value as Int:
            encodeDouble(Double(value))
        case let value as UInt:
            encodeDouble(Double(value))
        case let value as Int8:
            encodeDouble(Double(value))
        case let value as UInt8:
            encodeDouble(Double(value))
        case let value as Int16:
            encodeDouble(Double(value))
        case let value as UInt16:
            encodeDouble(Double(value))
        case let value as Int32:
            encodeDouble(Double(value))
        case let value as UInt32:
            encodeDouble(Double(value))
        case let value as Float:
            encodeDouble(Double(value))
        case let value as Double:
            encodeDouble(value)
        case let value as Date:
            encodeDate(value)
        case let value as String:
            encodeString(value)
        case let value as Bool:
            encodeBool(value)
        case let value as AsArray:
            encodeAsArray(value)
        case let value as AsObject:
            encodeAsObject(value)
        case nil:
            writeAmf0Type(value: .null)
        default:
            writeAmf0Type(value: .undefined)
        }
    }

    private func encodeDouble(_ value: Double) {
        writeAmf0Type(value: .number)
        writeDouble(value)
    }

    private func encodeBool(_ value: Bool) {
        writeBytes(Data([Amf0Type.bool.rawValue, value ? 0x01 : 0x00]))
    }

    private func encodeString(_ value: String) {
        let data = value.utf8Data
        if UInt32(data.count) > UInt32(UInt16.max) {
            writeAmf0Type(value: .longString)
            encodeLongString(data: data)
        } else {
            writeAmf0Type(value: .string)
            encodeShortString(data: data)
        }
    }

    private func encodeAsObject(_ value: AsObject) {
        writeAmf0Type(value: .object)
        for (key, data) in value {
            encodeShortString(key)
            encode(data)
        }
        encodeShortString("")
        writeAmf0Type(value: .objectEnd)
    }

    private func encodeAsArray(_: AsArray) {}

    private func encodeDate(_ value: Date) {
        writeAmf0Type(value: .date)
        writeDouble(value.timeIntervalSince1970 * 1000)
        writeUInt16(0)
    }

    private func encodeShortString(_ value: String) {
        encodeShortString(data: value.utf8Data)
    }

    private func encodeLongString(_ value: String) {
        encodeLongString(data: value.utf8Data)
    }

    private func encodeShortString(data: Data) {
        writeUInt16(UInt16(data.count))
        writeBytes(data)
    }

    private func encodeLongString(data: Data) {
        writeUInt32(UInt32(data.count))
        writeBytes(data)
    }

    private func writeAmf0Type(value: Amf0Type) {
        writeUInt8(value.rawValue)
    }
}

final class Amf0Decoder: ByteReader {
    func decode() throws -> Any? {
        let type = try readAmf0Type()
        position -= 1
        switch type {
        case .number:
            return try decodeDouble()
        case .bool:
            return try decodeBool()
        case .string:
            return try decodeString()
        case .object:
            return try decodeAsObject()
        case .null:
            position += 1
            return nil
        case .undefined:
            position += 1
            return kASUndefined
        case .reference:
            return nil
        case .ecmaArray:
            return try decodeAsArray()
        case .objectEnd:
            return nil
        case .strictArray:
            return try decodeAnyArray()
        case .date:
            return try decodeDate()
        case .longString:
            return try decodeString()
        case .unsupported:
            return nil
        case .xmlDocument:
            return try decodeAsXmlDocument()
        case .typedObject:
            return try decodeAny()
        case .avmplush:
            return nil
        }
    }

    func decodeInt() throws -> Int {
        try Int(decodeDouble())
    }

    func decodeString() throws -> String {
        switch try readAmf0Type() {
        case .string:
            return try decodeShortString()
        case .longString:
            return try decodeLongString()
        default:
            throw AmfError.decode
        }
    }

    func decodeAsObject() throws -> AsObject {
        var object = AsObject()
        switch try readAmf0Type() {
        case .null:
            return object
        case .object:
            break
        default:
            throw AmfError.decode
        }
        while true {
            let key = try decodeShortString()
            guard !key.isEmpty else {
                break
            }
            object[key] = try decode()
        }
        try parseObjectEnd()
        return object
    }

    private func decodeDouble() throws -> Double {
        guard try readAmf0Type() == .number else {
            throw AmfError.decode
        }
        return try readDouble()
    }

    private func decodeBool() throws -> Bool {
        guard try readAmf0Type() == .bool else {
            throw AmfError.decode
        }
        return try readUInt8() == 0x01
    }

    private func decodeAsArray() throws -> AsArray {
        switch try readAmf0Type() {
        case .null:
            return AsArray()
        case .ecmaArray:
            break
        default:
            throw AmfError.decode
        }
        let numberOfElements = try readUInt32()
        guard numberOfElements < 128 else {
            throw AmfError.arrayTooBig
        }
        var array = AsArray()
        for _ in 0 ..< numberOfElements {
            try array.set(key: decodeShortString(), value: decode())
        }
        guard try decodeShortString() == "" else {
            throw AmfError.decode
        }
        try parseObjectEnd()
        return array
    }

    private func parseObjectEnd() throws {
        if try readUInt8() != Amf0Type.objectEnd.rawValue {
            throw AmfError.notObjectEnd
        }
    }

    private func decodeAnyArray() throws -> [Any?] {
        guard try readAmf0Type() == .strictArray else {
            throw AmfError.decode
        }
        var result: [Any?] = []
        let count = try Int(readUInt32())
        for _ in 0 ..< count {
            try result.append(decode())
        }
        return result
    }

    private func decodeDate() throws -> Date {
        guard try readAmf0Type() == .date else {
            throw AmfError.decode
        }
        let date = try Date(timeIntervalSince1970: readDouble() / 1000)
        position += 2 // timezone offset
        return date
    }

    private func decodeAsXmlDocument() throws -> AsXmlDocument {
        guard try readAmf0Type() == .xmlDocument else {
            throw AmfError.decode
        }
        return try AsXmlDocument(data: decodeLongString())
    }

    private func decodeAny() throws -> Any {
        guard try readAmf0Type() == .typedObject else {
            throw AmfError.decode
        }
        let typeName = try decodeShortString()
        var result = AsObject()
        while true {
            let key = try decodeShortString()
            guard !key.isEmpty else {
                position += 1
                break
            }
            result[key] = try decode()
        }
        return try AsTypedObject.decode(typeName: typeName, data: result)
    }

    private func decodeShortString() throws -> String {
        return try readUtf8Bytes(Int(readUInt16()))
    }

    private func decodeLongString() throws -> String {
        return try readUtf8Bytes(Int(readUInt32()))
    }

    private func readAmf0Type() throws -> Amf0Type {
        guard let value = try Amf0Type(rawValue: readUInt8()) else {
            throw AmfError.decode
        }
        return value
    }
}
