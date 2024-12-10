import AVFoundation

final class RtmpSetChunkSizeMessage: RtmpMessage {
    var size: UInt32 = 0

    init() {
        super.init(type: .chunkSize)
    }

    init(_ size: UInt32) {
        super.init(type: .chunkSize)
        self.size = size
    }

    override func execute(_ connection: RtmpConnection, type _: RTMPChunkType) {
        connection.socket.maximumChunkSizeFromServer = Int(size)
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
