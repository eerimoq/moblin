import AVFoundation

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
