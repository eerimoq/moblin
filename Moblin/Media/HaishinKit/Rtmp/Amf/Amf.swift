import Foundation

typealias AsObject = [String: AsValue]

struct AsTypedObject: Equatable {
    static func decode(typeName _: String, data _: AsObject) throws -> AsTypedObject {
        return AsTypedObject()
    }
}

struct AsArray: Equatable {
    private(set) var items: [String: AsValue] = [:]

    mutating func set(key: String, value: AsValue) {
        items[key] = value
    }

    func get(key: String) throws -> AsValue {
        guard let value = items[key] else {
            throw "Not found"
        }
        return value
    }
}

struct AsXmlDocument: CustomStringConvertible {
    var description: String {
        data
    }

    private let data: String

    init(data: String) {
        self.data = data
    }
}

extension AsXmlDocument: Equatable {
    static func == (lhs: AsXmlDocument, rhs: AsXmlDocument) -> Bool {
        lhs.description == rhs.description
    }
}

struct AsXml: CustomStringConvertible {
    var description: String {
        data
    }

    private let data: String
}

extension AsXml: Equatable {
    static func == (lhs: AsXml, rhs: AsXml) -> Bool {
        lhs.description == rhs.description
    }
}

enum AsValue: Equatable {
    case number(Double)
    case bool(Bool)
    case string(String)
    case object(AsObject)
    case null
    case undefined
    case reference
    case ecmaArray(AsArray)
    case strictArray([AsValue])
    case date(Date)
    case unsupported
    case xmlDocument(AsXmlDocument)
    case typedObject(AsTypedObject)
    case avmplush
}

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
    func encode(_ value: AsValue) {
        switch value {
        case let .number(value):
            encodeDouble(value)
        case let .date(value):
            encodeDate(value)
        case let .string(value):
            encodeString(value)
        case let .bool(value):
            encodeBool(value)
        case let .ecmaArray(value):
            encodeAsArray(value)
        case let .object(value):
            encodeAsObject(value)
        case .null:
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
    func decode() throws -> AsValue {
        let type = try readAmf0Type()
        switch type {
        case .number:
            return try .number(decodeDoubleValue())
        case .bool:
            return try .bool(decodeBoolValue())
        case .string:
            return try .string(decodeStringValue())
        case .object:
            return try .object(decodeObjectValue())
        case .null:
            return .null
        case .undefined:
            return .undefined
        case .reference:
            return .reference
        case .ecmaArray:
            return try .ecmaArray(decodeEcmaArrayValue())
        case .strictArray:
            return try .strictArray(decodeStrictArrayValue())
        case .date:
            return try .date(decodeDateValue())
        case .longString:
            return try .string(decodeLongStringValue())
        case .unsupported:
            return .unsupported
        case .xmlDocument:
            return try .xmlDocument(decodeXmlDocumentValue())
        case .typedObject:
            return try .typedObject(decodeTypedObjectValue())
        case .avmplush:
            return .avmplush
        case .objectEnd:
            throw AmfError.decode
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
        let numberOfElements = try readNumberOfArrayElements()
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

    private func decodeStrictArrayValue() throws -> [AsValue] {
        let numberOfElements = try readNumberOfArrayElements()
        var array: [AsValue] = []
        for _ in 0 ..< numberOfElements {
            try array.append(decode())
        }
        return array
    }

    private func readNumberOfArrayElements() throws -> UInt32 {
        let numberOfElements = try readUInt32()
        guard numberOfElements < 128 else {
            throw AmfError.arrayTooBig
        }
        return numberOfElements
    }

    private func decodeDateValue() throws -> Date {
        let date = try Date(timeIntervalSince1970: readDouble() / 1000)
        _ = try readUInt16()
        return date
    }

    private func decodeXmlDocumentValue() throws -> AsXmlDocument {
        return try AsXmlDocument(data: decodeLongStringValue())
    }

    private func decodeTypedObjectValue() throws -> AsTypedObject {
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
