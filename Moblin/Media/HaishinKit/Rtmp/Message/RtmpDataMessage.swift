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
            let serializer = Amf0Encoder()
            if type == .amf3Data {
                serializer.writeUInt8(0)
            }
            serializer.encode(handlerName)
            for arg in arguments {
                serializer.encode(arg)
            }
            super.encoded = serializer.data
            return super.encoded
        }
        set {
            guard super.encoded != newValue else {
                return
            }
            if length == newValue.count {
                let decoder = Amf0Decoder(data: newValue)
                if type == .amf3Data {
                    decoder.position = 1
                }
                do {
                    handlerName = try decoder.decodeString()
                    while decoder.bytesAvailable > 0 {
                        try arguments.append(decoder.decode())
                    }
                } catch {
                    logger.error("\(decoder)")
                }
            }
            super.encoded = newValue
        }
    }
}
