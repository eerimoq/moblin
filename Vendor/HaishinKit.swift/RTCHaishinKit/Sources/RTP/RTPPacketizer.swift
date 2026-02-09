import AVFAudio
import CoreMedia

protocol RTPPacketizerDelegate: AnyObject {
    func packetizer(_ packetizer: some RTPPacketizer, didOutput buffer: CMSampleBuffer)
    func packetizer(_ packetizer: some RTPPacketizer, didOutput buffer: AVAudioCompressedBuffer, when: AVAudioTime)
}

protocol RTPPacketizer {
    associatedtype T: RTPPacketizerDelegate

    var delegate: T? { get set }
    var ssrc: UInt32 { get }
    var formatParameter: RTPFormatParameter { get set }

    func append(_ packet: RTPPacket)

    func append(_ buffer: CMSampleBuffer, lambda: (RTPPacket) -> Void)

    func append(_ buffer: AVAudioCompressedBuffer, when: AVAudioTime, lambda: (RTPPacket) -> Void)
}
