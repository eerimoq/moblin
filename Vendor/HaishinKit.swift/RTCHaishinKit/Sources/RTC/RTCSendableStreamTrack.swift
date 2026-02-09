import AVFoundation
import HaishinKit
import libdatachannel

actor RTCSendableStreamTrack: RTCStreamTrack {
    let id: String
    private let track: RTCTrack

    init(_ tid: Int32, id: String) throws {
        track = try RTCTrack(id: tid)
        self.id = id
    }

    func send(_ buffer: CMSampleBuffer) {
        track.send(buffer)
    }

    func send(_ buffer: AVAudioCompressedBuffer, when: AVAudioTime) {
        track.send(buffer, when: when)
    }

    func setDelegate(_ delegate: some RTCTrackDelegate) {
        track.delegate = delegate
    }
}
