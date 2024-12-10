import Foundation

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

    override func execute(_: RtmpConnection, type _: RTMPChunkType) {
        // connection.bandWidth = size
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
            size = UInt32(data: newValue[0 ..< 4]).bigEndian
            limit = Limit(rawValue: newValue[4]) ?? .unknown
            super.encoded = newValue
        }
    }
}
