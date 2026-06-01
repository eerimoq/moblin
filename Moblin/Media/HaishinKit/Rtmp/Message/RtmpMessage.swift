import AVFoundation

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
            RtmpAbortMessge()
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
