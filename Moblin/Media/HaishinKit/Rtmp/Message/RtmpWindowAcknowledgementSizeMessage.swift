import Foundation

final class RtmpWindowAcknowledgementSizeMessage: RtmpMessage {
    var size: UInt32 = 0

    init() {
        super.init(type: .windowAck)
    }

    init(_ size: UInt32) {
        super.init(type: .windowAck)
        self.size = size
    }

    override func execute(_ connection: RtmpConnection) {
        connection.windowSizeFromServer = Int64(size)
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
