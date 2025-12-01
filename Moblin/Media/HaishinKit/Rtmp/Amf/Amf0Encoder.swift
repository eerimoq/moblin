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
        switch type {
        case .number:
            return try decodeDoubleValue()
        case .bool:
            return try decodeBoolValue()
        case .string:
            return try decodeStringValue()
        case .object:
            return try decodeObjectValue()
        case .null:
            return nil
        case .undefined:
            return kASUndefined
        case .reference:
            return nil
        case .ecmaArray:
            return try decodeEcmaArrayValue()
        case .objectEnd:
            return nil
        case .strictArray:
            return try decodeStrictArrayValue()
        case .date:
            return try decodeDateValue()
        case .longString:
            return try decodeLongStringValue()
        case .unsupported:
            return nil
        case .xmlDocument:
            return try decodeXmlDocumentValue()
        case .typedObject:
            return try decodeTypedObjectValue()
        case .avmplush:
            return nil
        }
    }

    func decodeInt() throws -> Int {
        guard try readAmf0Type() == .number else {
            throw AmfError.decode
        }
        return try Int(decodeDoubleValue())
    }

    func decodeString() throws -> String {
        switch try readAmf0Type() {
        case .string:
            return try decodeStringValue()
        case .longString:
            return try decodeLongStringValue()
        default:
            throw AmfError.decode
        }
    }

    func decodeObject() throws -> AsObject {
        switch try readAmf0Type() {
        case .null:
            return AsObject()
        case .object:
            return try decodeObjectValue()
        default:
            throw AmfError.decode
        }
    }

    private func decodeObjectValue() throws -> AsObject {
        var object = AsObject()
        while true {
            let key = try decodeStringValue()
            guard !key.isEmpty else {
                break
            }
            object[key] = try decode()
        }
        try parseObjectEnd()
        return object
    }

    private func decodeDoubleValue() throws -> Double {
        return try readDouble()
    }

    private func decodeBoolValue() throws -> Bool {
        return try readUInt8() == 0x01
    }

    private func decodeEcmaArrayValue() throws -> AsArray {
        let numberOfElements = try readUInt32()
        guard numberOfElements < 128 else {
            throw AmfError.arrayTooBig
        }
        var array = AsArray()
        for _ in 0 ..< numberOfElements {
            try array.set(key: decodeStringValue(), value: decode())
        }
        guard try decodeStringValue() == "" else {
            throw AmfError.decode
        }
        try parseObjectEnd()
        return array
    }

    private func decodeStrictArrayValue() throws -> [Any?] {
        var result: [Any?] = []
        let count = try Int(readUInt32())
        for _ in 0 ..< count {
            try result.append(decode())
        }
        return result
    }

    private func decodeDateValue() throws -> Date {
        let date = try Date(timeIntervalSince1970: readDouble() / 1000)
        position += 2 // timezone offset
        return date
    }

    private func decodeXmlDocumentValue() throws -> AsXmlDocument {
        return try AsXmlDocument(data: decodeLongStringValue())
    }

    private func decodeTypedObjectValue() throws -> Any {
        let typeName = try decodeStringValue()
        var result = AsObject()
        while true {
            let key = try decodeStringValue()
            guard !key.isEmpty else {
                position += 1
                break
            }
            result[key] = try decode()
        }
        return try AsTypedObject.decode(typeName: typeName, data: result)
    }

    private func decodeStringValue() throws -> String {
        return try readUtf8Bytes(Int(readUInt16()))
    }

    private func decodeLongStringValue() throws -> String {
        return try readUtf8Bytes(Int(readUInt32()))
    }

    private func readAmf0Type() throws -> Amf0Type {
        guard let value = try Amf0Type(rawValue: readUInt8()) else {
            throw AmfError.decode
        }
        return value
    }

    private func parseObjectEnd() throws {
        if try readUInt8() != Amf0Type.objectEnd.rawValue {
            throw AmfError.notObjectEnd
        }
    }
}
