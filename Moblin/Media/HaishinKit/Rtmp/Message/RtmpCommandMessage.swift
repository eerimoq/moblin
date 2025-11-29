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
    private var commandName: RtmpCommandName = .close
    private(set) var transactionId: Int = 0
    private var commandObject: AsObject?
    private var arguments: [Any?] = []

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

    override func execute(_ connection: RtmpConnection) {
        guard let responder = connection.callCompletions.removeValue(forKey: transactionId) else {
            switch commandName {
            case .close:
                connection.disconnect()
            default:
                if let data = arguments.first as? AsObject?, let data {
                    connection.gotCommand(data: data)
                }
            }
            return
        }
        switch commandName {
        case .result:
            responder(arguments)
        default:
            break
        }
    }

    override var encoded: Data {
        get {
            guard super.encoded.isEmpty else {
                return super.encoded
            }
            let serializer = Amf0Serializer()
            if type == .amf3Command {
                serializer.writeUInt8(0)
            }
            serializer.serialize(commandName.rawValue)
            serializer.serialize(transactionId)
            serializer.serialize(commandObject)
            for argument in arguments {
                serializer.serialize(argument)
            }
            super.encoded = serializer.data
            return super.encoded
        }
        set {
            if length == newValue.count {
                let deserializer = Amf0Deserializer(data: newValue)
                do {
                    if type == .amf3Command {
                        deserializer.position = 1
                    }
                    commandName = try RtmpCommandName(rawValue: deserializer.deserializeString()) ?? .unknown
                    transactionId = try deserializer.deserializeInt()
                    commandObject = try deserializer.deserializeAsObject()
                    arguments.removeAll()
                    while deserializer.bytesAvailable > 0 {
                        try arguments.append(deserializer.deserialize())
                    }
                } catch {
                    logger.error("rtmp: \(error)")
                }
            }
            super.encoded = newValue
        }
    }
}
