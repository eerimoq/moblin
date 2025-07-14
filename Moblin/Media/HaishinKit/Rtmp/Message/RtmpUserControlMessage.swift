import Foundation

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

    override func execute(_ connection: RtmpConnection) {
        switch event {
        case .ping:
            _ = connection.socket.write(chunk: RtmpChunk(
                type: .zero,
                chunkStreamId: RtmpChunk.ChunkStreamId.control.rawValue,
                message: RtmpUserControlMessage(event: .pong, value: value)
            ))
        default:
            break
        }
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
            if length == newValue.count {
                if let event = Event(rawValue: newValue[1]) {
                    self.event = event
                }
                value = Int32(data: newValue[2 ..< newValue.count]).bigEndian
            }
            super.encoded = newValue
        }
    }
}
