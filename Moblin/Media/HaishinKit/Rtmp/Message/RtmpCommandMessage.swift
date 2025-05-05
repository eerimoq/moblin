import Foundation

final class RtmpCommandMessage: RtmpMessage {
    var commandName: String = ""
    var transactionId: Int = 0
    var commandObject: AsObject?
    var arguments: [Any?] = []

    init(objectEncoding: RtmpObjectEncoding) {
        super.init(type: objectEncoding.commandType)
    }

    init(
        streamId: UInt32,
        transactionId: Int,
        objectEncoding: RtmpObjectEncoding,
        commandName: String,
        commandObject: AsObject?,
        arguments: [Any?]
    ) {
        self.transactionId = transactionId
        self.commandName = commandName
        self.commandObject = commandObject
        self.arguments = arguments
        super.init(type: objectEncoding.commandType)
        self.streamId = streamId
    }

    override func execute(_ connection: RtmpConnection) {
        guard let responder = connection.callCompletions.removeValue(forKey: transactionId) else {
            switch commandName {
            case "close":
                connection.disconnectInternal()
            default:
                connection.dispatch(.rtmpStatus, data: arguments.first as Any?)
            }
            return
        }
        switch commandName {
        case "_result":
            responder(arguments)
        case "_error":
            // Should probably do something.
            break
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
            serializer
                .serialize(commandName)
                .serialize(transactionId)
                .serialize(commandObject)
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
                    commandName = try deserializer.deserialize()
                    transactionId = try deserializer.deserialize()
                    commandObject = try deserializer.deserialize()
                    arguments.removeAll()
                    if deserializer.bytesAvailable > 0 {
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
