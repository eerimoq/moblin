import Foundation

final class RtmpDataMessage: RtmpMessage {
    var handlerName: String = ""
    var arguments: [Any?] = []

    init(dataType: RtmpMessageType) {
        super.init(type: dataType)
    }

    init(
        streamId: UInt32,
        dataType: RtmpMessageType,
        timestamp: UInt32,
        handlerName: String,
        arguments: [Any?] = []
    ) {
        self.handlerName = handlerName
        self.arguments = arguments
        super.init(type: dataType)
        self.timestamp = timestamp
        self.streamId = streamId
    }

    override var encoded: Data {
        get {
            guard super.encoded.isEmpty else {
                return super.encoded
            }
            let serializer = Amf0Serializer()
            if type == .amf3Data {
                serializer.writeUInt8(0)
            }
            serializer.serialize(handlerName)
            for arg in arguments {
                serializer.serialize(arg)
            }
            super.encoded = serializer.data
            return super.encoded
        }
        set {
            guard super.encoded != newValue else {
                return
            }
            if length == newValue.count {
                let deserializer = Amf0Deserializer(data: newValue)
                if type == .amf3Data {
                    deserializer.position = 1
                }
                do {
                    handlerName = try deserializer.deserializeString()
                    while deserializer.bytesAvailable > 0 {
                        try arguments.append(deserializer.deserialize())
                    }
                } catch {
                    logger.error("\(deserializer)")
                }
            }
            super.encoded = newValue
        }
    }
}
