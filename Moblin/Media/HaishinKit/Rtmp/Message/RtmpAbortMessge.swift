import AVFoundation

final class RtmpAbortMessge: RtmpMessage {
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
