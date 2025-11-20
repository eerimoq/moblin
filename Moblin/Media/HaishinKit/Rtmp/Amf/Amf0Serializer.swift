import Foundation

/**
 -seealso: http://wwwimages.adobe.com/content/dam/Adobe/en/devnet/amf/pdf/amf0-file-format-specification.pdf
 */

enum AmfSerializerError: Error {
    case deserialize
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

final class Amf0Serializer: ByteWriter {
    func serialize(_ value: Any?) {
        switch value {
        case let value as Int:
            serializeDouble(Double(value))
        case let value as UInt:
            serializeDouble(Double(value))
        case let value as Int8:
            serializeDouble(Double(value))
        case let value as UInt8:
            serializeDouble(Double(value))
        case let value as Int16:
            serializeDouble(Double(value))
        case let value as UInt16:
            serializeDouble(Double(value))
        case let value as Int32:
            serializeDouble(Double(value))
        case let value as UInt32:
            serializeDouble(Double(value))
        case let value as Float:
            serializeDouble(Double(value))
        case let value as Double:
            serializeDouble(value)
        case let value as Date:
            serializeDate(value)
        case let value as String:
            serializeString(value)
        case let value as Bool:
            serializeBool(value)
        case let value as AsArray:
            serializeAsArray(value)
        case let value as AsObject:
            serializeAsObject(value)
        case nil:
            writeAmf0Type(value: .null)
        default:
            writeAmf0Type(value: .undefined)
        }
    }

    private func serializeDouble(_ value: Double) {
        writeAmf0Type(value: .number)
        writeDouble(value)
    }

    private func serializeBool(_ value: Bool) {
        writeBytes(Data([Amf0Type.bool.rawValue, value ? 0x01 : 0x00]))
    }

    private func serializeString(_ value: String) {
        let isLong: Bool = UInt32(UInt16.max) < UInt32(value.count)
        writeAmf0Type(value: isLong ? .longString : .string)
        serializeUTF8(value, isLong)
    }

    private func serializeAsObject(_ value: AsObject) {
        writeAmf0Type(value: .object)
        for (key, data) in value {
            serializeUTF8(key, false)
            serialize(data)
        }
        serializeUTF8("", false)
        writeAmf0Type(value: .objectEnd)
    }

    private func serializeAsArray(_: AsArray) {}

    private func serializeDate(_ value: Date) {
        writeAmf0Type(value: .date)
        writeDouble(value.timeIntervalSince1970 * 1000)
        writeUInt16(0)
    }

    private func serializeUTF8(_ value: String, _ isLong: Bool) {
        let utf8 = Data(value.utf8)
        if isLong {
            writeUInt32(UInt32(utf8.count))
        } else {
            writeUInt16(UInt16(utf8.count))
        }
        writeBytes(utf8)
    }

    private func writeAmf0Type(value: Amf0Type) {
        writeUInt8(value.rawValue)
    }
}

final class Amf0Deserializer: ByteReader {
    func deserialize() throws -> Any? {
        let type = try readAmf0Type()
        position -= 1
        switch type {
        case .number:
            return try deserializeDouble()
        case .bool:
            return try deserializeBool()
        case .string:
            return try deserializeString()
        case .object:
            return try deserializeAsObject()
        case .null:
            position += 1
            return nil
        case .undefined:
            position += 1
            return kASUndefined
        case .reference:
            return nil
        case .ecmaArray:
            return try deserializeAsArray()
        case .objectEnd:
            return nil
        case .strictArray:
            return try deserializeAnyArray()
        case .date:
            return try deserializeDate()
        case .longString:
            return try deserializeString()
        case .unsupported:
            return nil
        case .xmlDocument:
            return try deserializeAsXmlDocument()
        case .typedObject:
            return try deserializeAny()
        case .avmplush:
            return nil
        }
    }

    private func deserializeDouble() throws -> Double {
        guard try readAmf0Type() == .number else {
            throw AmfSerializerError.deserialize
        }
        return try readDouble()
    }

    func deserializeInt() throws -> Int {
        try Int(deserializeDouble())
    }

    private func deserializeBool() throws -> Bool {
        guard try readAmf0Type() == .bool else {
            throw AmfSerializerError.deserialize
        }
        return try readUInt8() == 0x01
    }

    func deserializeString() throws -> String {
        switch try readAmf0Type() {
        case .string:
            return try deserializeUTF8(false)
        case .longString:
            return try deserializeUTF8(true)
        default:
            return ""
        }
    }

    func deserializeAsObject() throws -> AsObject {
        var result = AsObject()
        switch try readAmf0Type() {
        case .null:
            return result
        case .object:
            break
        default:
            throw AmfSerializerError.deserialize
        }
        while true {
            let key: String = try deserializeUTF8(false)
            guard !key.isEmpty else {
                position += 1
                break
            }
            result[key] = try deserialize()
        }
        return result
    }

    private func deserializeAsArray() throws -> AsArray {
        switch try readAmf0Type() {
        case .null:
            return AsArray()
        case .ecmaArray:
            break
        default:
            throw AmfSerializerError.deserialize
        }
        var result = try AsArray(count: Int(readUInt32()))
        while true {
            let key = try deserializeUTF8(false)
            guard !key.isEmpty else {
                position += 1
                break
            }
            result[key] = try deserialize()
        }
        return result
    }

    private func deserializeAnyArray() throws -> [Any?] {
        guard try readAmf0Type() == .strictArray else {
            throw AmfSerializerError.deserialize
        }
        var result: [Any?] = []
        let count = try Int(readUInt32())
        for _ in 0 ..< count {
            try result.append(deserialize())
        }
        return result
    }

    private func deserializeDate() throws -> Date {
        guard try readAmf0Type() == .date else {
            throw AmfSerializerError.deserialize
        }
        let date = try Date(timeIntervalSince1970: readDouble() / 1000)
        position += 2 // timezone offset
        return date
    }

    private func deserializeAsXmlDocument() throws -> AsXmlDocument {
        guard try readAmf0Type() == .xmlDocument else {
            throw AmfSerializerError.deserialize
        }
        return try AsXmlDocument(data: deserializeUTF8(true))
    }

    private func deserializeAny() throws -> Any {
        guard try readAmf0Type() == .typedObject else {
            throw AmfSerializerError.deserialize
        }
        let typeName = try deserializeUTF8(false)
        var result = AsObject()
        while true {
            let key: String = try deserializeUTF8(false)
            guard !key.isEmpty else {
                position += 1
                break
            }
            result[key] = try deserialize()
        }
        return try AsTypedObject.decode(typeName: typeName, data: result)
    }

    private func deserializeUTF8(_ isLong: Bool) throws -> String {
        let length = try isLong ? Int(readUInt32()) : Int(readUInt16())
        return try readUTF8Bytes(length)
    }

    private func readAmf0Type() throws -> Amf0Type {
        guard let value = try Amf0Type(rawValue: readUInt8()) else {
            throw AmfSerializerError.deserialize
        }
        return value
    }
}
