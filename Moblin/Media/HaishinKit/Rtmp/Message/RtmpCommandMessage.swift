import Foundation

final class RtmpCommandMessage: RtmpMessage {
    var commandName: String = ""
    var transactionId: Int = 0
    var commandObject: AsObject?
    var arguments: [Any?] = []

    private var serializer = Amf0Serializer()

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
            serializer.clear()
            return super.encoded
        }
        set {
            if length == newValue.count {
                serializer.writeBytes(newValue)
                serializer.position = 0
                do {
                    if type == .amf3Command {
                        serializer.position = 1
                    }
                    commandName = try serializer.deserialize()
                    transactionId = try serializer.deserialize()
                    commandObject = try serializer.deserialize()
                    arguments.removeAll()
                    if serializer.bytesAvailable > 0 {
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
