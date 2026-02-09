import Foundation

enum StunMessageType: UInt16 {
    case bindingRequest = 0x0001
    case bindingResponse = 0x0101
    case bindingErrorResponse = 0x0111
}

enum StunAttributeType: UInt16 {
    case mappedAddress = 0x0001
    case username = 0x0006
    case messageIntegrity = 0x0008
    case errorCode = 0x0009
    case xorMappedAddress = 0x0020
    case priority = 0x0024
    case useCandidate = 0x0025
    case fingerprint = 0x8028
    case iceControlled = 0x8029
    case iceControlling = 0x802A
}

struct StunAttribute {
    let type: UInt16
    let value: Data
}

private let stunMagicCookie: UInt32 = 0x2112_A442

struct StunMessage {
    let type: StunMessageType
    let transactionId: Data
    var attributes: [StunAttribute]

    init(type: StunMessageType, transactionId: Data? = nil, attributes: [StunAttribute] = []) {
        self.type = type
        self.transactionId = transactionId ?? StunMessage.generateTransactionId()
        self.attributes = attributes
    }

    static func generateTransactionId() -> Data {
        var data = Data(count: 12)
        for i in 0 ..< 12 {
            data[i] = UInt8.random(in: 0 ... 255)
        }
        return data
    }

    func encode() -> Data {
        var attributeData = Data()
        for attribute in attributes {
            var attrData = Data(count: 4)
            attrData[0] = UInt8(attribute.type >> 8)
            attrData[1] = UInt8(attribute.type & 0xFF)
            let length = UInt16(attribute.value.count)
            attrData[2] = UInt8(length >> 8)
            attrData[3] = UInt8(length & 0xFF)
            attrData.append(attribute.value)
            let padding = (4 - (attribute.value.count % 4)) % 4
            if padding > 0 {
                attrData.append(Data(count: padding))
            }
            attributeData.append(attrData)
        }
        var header = Data(count: 20)
        header[0] = UInt8(type.rawValue >> 8)
        header[1] = UInt8(type.rawValue & 0xFF)
        let messageLength = UInt16(attributeData.count)
        header[2] = UInt8(messageLength >> 8)
        header[3] = UInt8(messageLength & 0xFF)
        header[4] = UInt8(stunMagicCookie >> 24)
        header[5] = UInt8((stunMagicCookie >> 16) & 0xFF)
        header[6] = UInt8((stunMagicCookie >> 8) & 0xFF)
        header[7] = UInt8(stunMagicCookie & 0xFF)
        header.replaceSubrange(8 ..< 20, with: transactionId)
        var result = header
        result.append(attributeData)
        return result
    }

    static func decode(from data: Data) -> StunMessage? {
        guard data.count >= 20 else {
            return nil
        }
        let typeValue = UInt16(data[0]) << 8 | UInt16(data[1])
        guard let type = StunMessageType(rawValue: typeValue) else {
            return nil
        }
        let magic = UInt32(data[4]) << 24 | UInt32(data[5]) << 16 |
            UInt32(data[6]) << 8 | UInt32(data[7])
        guard magic == stunMagicCookie else {
            return nil
        }
        let messageLength = Int(UInt16(data[2]) << 8 | UInt16(data[3]))
        guard data.count >= 20 + messageLength else {
            return nil
        }
        let transactionId = data[8 ..< 20]
        var attributes: [StunAttribute] = []
        var offset = 20
        while offset + 4 <= 20 + messageLength {
            let attrType = UInt16(data[offset]) << 8 | UInt16(data[offset + 1])
            let attrLength = Int(UInt16(data[offset + 2]) << 8 | UInt16(data[offset + 3]))
            offset += 4
            guard offset + attrLength <= data.count else {
                break
            }
            let value = data[offset ..< offset + attrLength]
            attributes.append(StunAttribute(type: attrType, value: Data(value)))
            offset += attrLength
            let padding = (4 - (attrLength % 4)) % 4
            offset += padding
        }
        return StunMessage(type: type, transactionId: Data(transactionId), attributes: attributes)
    }
}

func stunCreateBindingRequest(username: String, iceControlling: UInt64, priority: UInt32) -> StunMessage {
    var attributes: [StunAttribute] = []
    if let usernameData = username.data(using: .utf8) {
        attributes.append(StunAttribute(type: StunAttributeType.username.rawValue, value: usernameData))
    }
    var priorityData = Data(count: 4)
    priorityData[0] = UInt8(priority >> 24)
    priorityData[1] = UInt8((priority >> 16) & 0xFF)
    priorityData[2] = UInt8((priority >> 8) & 0xFF)
    priorityData[3] = UInt8(priority & 0xFF)
    attributes.append(StunAttribute(type: StunAttributeType.priority.rawValue, value: priorityData))
    var controllingData = Data(count: 8)
    for i in 0 ..< 8 {
        controllingData[i] = UInt8((iceControlling >> (56 - i * 8)) & 0xFF)
    }
    attributes.append(StunAttribute(
        type: StunAttributeType.iceControlling.rawValue,
        value: controllingData
    ))
    attributes.append(StunAttribute(type: StunAttributeType.useCandidate.rawValue, value: Data()))
    return StunMessage(type: .bindingRequest, attributes: attributes)
}

func stunIsBindingResponse(_ data: Data) -> Bool {
    guard data.count >= 20 else {
        return false
    }
    let typeValue = UInt16(data[0]) << 8 | UInt16(data[1])
    return typeValue == StunMessageType.bindingResponse.rawValue
}
