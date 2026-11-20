import Foundation

enum RtmpMessageType: UInt8 {
    case chunkSize = 0x01
    case abort = 0x02
    case ack = 0x03
    case user = 0x04
    case windowAck = 0x05
    case bandwidth = 0x06
    case audio = 0x08
    case video = 0x09
    case amf3Data = 0x0F
    case amf3Command = 0x11
    case amf0Data = 0x12
    case amf0Command = 0x14
    case aggregate = 0x16
}

class RtmpMessage {
    let type: RtmpMessageType
    var length: Int = 0
    var streamId: UInt32 = 0
    var timestamp: UInt32 = 0
    var encoded = Data()

    init(type: RtmpMessageType) {
        self.type = type
    }

    static func create(type: RtmpMessageType) -> RtmpMessage {
        switch type {
        case .chunkSize:
            RtmpSetChunkSizeMessage()
        case .abort:
            RtmpAbortMessage()
        case .ack:
            RtmpAcknowledgementMessage()
        case .user:
            RtmpUserControlMessage()
        case .windowAck:
            RtmpWindowAcknowledgementSizeMessage()
        case .bandwidth:
            RtmpSetPeerBandwidthMessage()
        case .audio:
            RtmpAudioMessage()
        case .video:
            RtmpVideoMessage()
        case .amf3Data:
            RtmpDataMessage(dataType: .amf3Data)
        case .amf3Command:
            RtmpCommandMessage(commandType: .amf3Command)
        case .amf0Data:
            RtmpDataMessage(dataType: .amf0Data)
        case .amf0Command:
            RtmpCommandMessage(commandType: .amf0Command)
        case .aggregate:
            RtmpAggregateMessage()
        }
    }
}

final class RtmpSetChunkSizeMessage: RtmpMessage {
    var size: UInt32 = 0

    init() {
        super.init(type: .chunkSize)
    }

    init(_ size: UInt32) {
        super.init(type: .chunkSize)
        self.size = size
    }

    override var encoded: Data {
        get {
            guard super.encoded.isEmpty else {
                return super.encoded
            }
            super.encoded = size.bigEndian.data
            return super.encoded
        }
        set {
            if super.encoded == newValue {
                return
            }
            size = UInt32(data: newValue).bigEndian
            super.encoded = newValue
        }
    }
}

final class RtmpAbortMessage: RtmpMessage {
    var chunkStreamId: UInt32 = 0

    init() {
        super.init(type: .abort)
    }

    override var encoded: Data {
        get {
            guard super.encoded.isEmpty else {
                return super.encoded
            }
            super.encoded = chunkStreamId.bigEndian.data
            return super.encoded
        }
        set {
            if super.encoded == newValue {
                return
            }
            chunkStreamId = UInt32(data: newValue).bigEndian
            super.encoded = newValue
        }
    }
}

final class RtmpAcknowledgementMessage: RtmpMessage {
    var sequence: UInt32 = 0

    init() {
        super.init(type: .ack)
    }

    override var encoded: Data {
        get {
            guard super.encoded.isEmpty else {
                return super.encoded
            }
            super.encoded = sequence.bigEndian.data
            return super.encoded
        }
        set {
            if super.encoded == newValue {
                return
            }
            sequence = UInt32(data: newValue).bigEndian
            super.encoded = newValue
        }
    }
}

final class RtmpUserControlMessage: RtmpMessage {
    enum Event: UInt8 {
        case streamBegin = 0x00
        case streamEof = 0x01
        case streamDry = 0x02
        case setBuffer = 0x03
        case recorded = 0x04
        case ping = 0x06
        case pong = 0x07
        case bufferEmpty = 0x1F
        case bufferFull = 0x20
        case unknown = 0xFF

        var bytes: [UInt8] {
            [0x00, rawValue]
        }
    }

    var event: Event = .unknown
    var value: Int32 = 0

    init() {
        super.init(type: .user)
    }

    init(event: Event, value: Int32) {
        super.init(type: .user)
        self.event = event
        self.value = value
    }

    override var encoded: Data {
        get {
            guard super.encoded.isEmpty else {
                return super.encoded
            }
            super.encoded.removeAll()
            super.encoded += event.bytes
            super.encoded += value.bigEndian.data
            return super.encoded
        }
        set {
            if super.encoded == newValue {
                return
            }
            if length == newValue.count, newValue.count >= 2 {
                if let event = Event(rawValue: newValue[1]) {
                    self.event = event
                }
                value = Int32(data: newValue[2 ..< newValue.count]).bigEndian
            }
            super.encoded = newValue
        }
    }
}

final class RtmpWindowAcknowledgementSizeMessage: RtmpMessage {
    var size: UInt32 = 0

    init() {
        super.init(type: .windowAck)
    }

    init(_ size: UInt32) {
        super.init(type: .windowAck)
        self.size = size
    }

    override var encoded: Data {
        get {
            guard super.encoded.isEmpty else {
                return super.encoded
            }
            super.encoded = size.bigEndian.data
            return super.encoded
        }
        set {
            if super.encoded == newValue {
                return
            }
            size = UInt32(data: newValue).bigEndian
            super.encoded = newValue
        }
    }
}

final class RtmpSetPeerBandwidthMessage: RtmpMessage {
    enum Limit: UInt8 {
        case hard = 0x00
        case soft = 0x01
        case dynamic = 0x02
        case unknown = 0xFF
    }

    var size: UInt32 = 0
    var limit: Limit = .hard

    init() {
        super.init(type: .bandwidth)
    }

    init(size: UInt32, limit: Limit) {
        super.init(type: .bandwidth)
        self.size = size
        self.limit = limit
    }

    override var encoded: Data {
        get {
            guard super.encoded.isEmpty else {
                return super.encoded
            }
            var payload = Data()
            payload.append(size.bigEndian.data)
            payload.append(limit.rawValue)
            super.encoded = payload
            return super.encoded
        }
        set {
            if super.encoded == newValue {
                return
            }
            if newValue.count >= 5 {
                size = UInt32(data: newValue[0 ..< 4]).bigEndian
                limit = Limit(rawValue: newValue[4]) ?? .unknown
            }
            super.encoded = newValue
        }
    }
}

final class RtmpAudioMessage: RtmpMessage {
    init() {
        super.init(type: .audio)
    }

    init(streamId: UInt32, timestamp: UInt32, payload: Data) {
        super.init(type: .audio)
        self.streamId = streamId
        self.timestamp = timestamp
        encoded = payload
    }
}

final class RtmpVideoMessage: RtmpMessage {
    init() {
        super.init(type: .video)
    }

    init(streamId: UInt32, timestamp: UInt32, payload: Data) {
        super.init(type: .video)
        self.streamId = streamId
        self.timestamp = timestamp
        encoded = payload
    }
}

final class RtmpDataMessage: RtmpMessage, @unchecked Sendable {
    var handlerName: String = ""
    var arguments: [AsValue] = []

    init(dataType: RtmpMessageType) {
        super.init(type: dataType)
    }

    init(
        streamId: UInt32,
        dataType: RtmpMessageType,
        timestamp: UInt32,
        handlerName: String,
        arguments: [AsValue] = []
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
            serializer.encode(.string(handlerName))
            for argument in arguments {
                serializer.encode(argument)
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
                    logger.info("rtmp-data-message: \(decoder)")
                }
            }
            super.encoded = newValue
        }
    }
}

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
    private(set) var commandName: RtmpCommandName = .unknown
    private(set) var transactionId: Int = 0
    private(set) var commandObject: AsObject?
    private(set) var arguments: [AsValue] = []

    init(commandType: RtmpMessageType) {
        super.init(type: commandType)
    }

    init(
        streamId: UInt32,
        transactionId: Int,
        commandType: RtmpMessageType,
        commandName: RtmpCommandName,
        commandObject: AsObject?,
        arguments: [AsValue]
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
            serializer.encode(.string(commandName.rawValue))
            serializer.encode(.number(Double(transactionId)))
            if let commandObject {
                serializer.encode(.object(commandObject))
            } else {
                serializer.encode(.null)
            }
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
                    commandObject = try decoder.decodeObject()
                    arguments.removeAll()
                    while decoder.bytesAvailable > 0 {
                        try arguments.append(decoder.decode())
                    }
                } catch {
                    logger.info("rtmp: Command message error: \(error): \(newValue.hexString())")
                    commandName = .unknown
                    commandObject = nil
                    arguments.removeAll()
                }
            }
            super.encoded = newValue
        }
    }
}

final class RtmpAggregateMessage: RtmpMessage {
    init() {
        super.init(type: .aggregate)
    }
}
