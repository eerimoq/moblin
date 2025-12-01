import Foundation

enum RtmpCommandName: String {
    case connect
    case close
    case result = "_result"
    case error = "_error"
    case publish
    case createStream
    case releaseStream
    case fcPublish = "FCPublish"
    case fcUnpublish = "FCUnpublish"
    case deleteStream
    case closeStream
    case onStatus
    case onFcPublish = "onFCPublish"
    case unknown
}

final class RtmpCommandMessage: RtmpMessage {
    private(set) var commandName: RtmpCommandName = .close
    private(set) var transactionId: Int = 0
    private(set) var commandObject: AsObject?
    private(set) var arguments: [Any?] = []

    init(commandType: RtmpMessageType) {
        super.init(type: commandType)
    }

    init(
        streamId: UInt32,
        transactionId: Int,
        commandType: RtmpMessageType,
        commandName: RtmpCommandName,
        commandObject: AsObject?,
        arguments: [Any?]
    ) {
        self.transactionId = transactionId
        self.commandName = commandName
        self.commandObject = commandObject
        self.arguments = arguments
        super.init(type: commandType)
        self.streamId = streamId
    }

    override var encoded: Data {
        get {
            guard super.encoded.isEmpty else {
                return super.encoded
            }
            let serializer = Amf0Encoder()
            if type == .amf3Command {
                serializer.writeUInt8(0)
            }
            serializer.encode(commandName.rawValue)
            serializer.encode(transactionId)
            serializer.encode(commandObject)
            for argument in arguments {
                serializer.encode(argument)
            }
            super.encoded = serializer.data
            return super.encoded
        }
        set {
            if length == newValue.count {
                let decoder = Amf0Decoder(data: newValue)
                do {
                    if type == .amf3Command {
                        decoder.position = 1
                    }
                    commandName = try RtmpCommandName(rawValue: decoder.decodeString()) ?? .unknown
                    transactionId = try decoder.decodeInt()
                    commandObject = try decoder.decodeAsObject()
                    arguments.removeAll()
                    while decoder.bytesAvailable > 0 {
                        try arguments.append(decoder.decode())
                    }
                } catch {
                    logger.error("rtmp: \(error)")
                }
            }
            super.encoded = newValue
        }
    }
}
