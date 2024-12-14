import Foundation

final class RtmpDataMessage: RtmpMessage {
    var handlerName: String = ""
    var arguments: [Any?] = []

    private var serializer = Amf0Serializer()

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
        guard let stream = connection.streams.first(where: { $0.id == streamId }) else {
            return
        }
        stream.info.byteCount.mutate { $0 += Int64(encoded.count) }
    }

    override var encoded: Data {
        get {
            guard super.encoded.isEmpty else {
                return super.encoded
            }
            if type == .amf3Data {
                serializer.writeUInt8(0)
            }
            _ = serializer.serialize(handlerName)
            for arg in arguments {
                serializer.serialize(arg)
            }
            super.encoded = serializer.data
            serializer.clear()
            return super.encoded
        }
        set {
            guard super.encoded != newValue else {
                return
            }
            if length == newValue.count {
                serializer.writeBytes(newValue)
                serializer.position = 0
                if type == .amf3Data {
                    serializer.position = 1
                }
                do {
                    handlerName = try serializer.deserialize()
                    while serializer.bytesAvailable > 0 {
                        try arguments.append(serializer.deserialize())
                    }
                } catch {
                    logger.error("\(serializer)")
                }
                serializer.clear()
            }
            super.encoded = newValue
        }
    }
}
