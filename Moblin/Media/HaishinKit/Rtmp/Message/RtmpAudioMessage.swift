import AVFoundation

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
