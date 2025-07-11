import Foundation

final class RtmpDataMessage: RtmpMessage {
    var handlerName: String = ""
    var arguments: [Any?] = []

    init(objectEncoding: RtmpObjectEncoding) {
        super.init(type: objectEncoding.dataType)
    }

    init(
        streamId: UInt32,
        objectEncoding: RtmpObjectEncoding,
        timestamp: UInt32,
        handlerName: String,
        arguments: [Any?] = []
    ) {
        self.handlerName = handlerName
        self.arguments = arguments
        super.init(type: objectEncoding.dataType)
        self.timestamp = timestamp
        self.streamId = streamId
    }

    override func execute(_ connection: RtmpConnection) {
        connection.stream?.info.byteCount.mutate { $0 += Int64(encoded.count) }
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
            _ = serializer.serialize(handlerName)
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
                    handlerName = try deserializer.deserialize()
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
