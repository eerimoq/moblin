import AVFAudio
import CoreMedia
import Foundation
import HaishinKit

private let kRTPOpusPacketizer_sampleRate = 48000.0

final class RTPOpusPacketizer<T: RTPPacketizerDelegate>: RTPPacketizer {
    let ssrc: UInt32
    let payloadType: UInt8
    weak var delegate: T?
    var formatParameter = RTPFormatParameter()
    private var timestamp: RTPTimestamp = .init(kRTPOpusPacketizer_sampleRate)
    private var audioFormat: AVAudioFormat?
    private var sequenceNumber: UInt16 = 0
    private lazy var jitterBuffer: RTPJitterBuffer<RTPOpusPacketizer> = {
        let jitterBuffer = RTPJitterBuffer<RTPOpusPacketizer>()
        jitterBuffer.delegate = self
        return jitterBuffer
    }()

    init(ssrc: UInt32, payloadType: UInt8) {
        self.ssrc = ssrc
        self.payloadType = payloadType
    }

    func append(_ packet: RTPPacket) {
        jitterBuffer.append(packet)
    }

    func append(_ buffer: CMSampleBuffer, lambda: (RTPPacket) -> Void) {
    }

    func append(_ buffer: AVAudioCompressedBuffer, when: AVAudioTime, lambda: (RTPPacket) -> Void) {
        lambda(RTPPacket(
            version: RTPPacket.version,
            padding: false,
            extension: false,
            cc: 0,
            marker: true,
            payloadType: payloadType,
            sequenceNumber: sequenceNumber,
            timestamp: timestamp.convert(when),
            ssrc: ssrc,
            payload: Data(
                bytes: buffer.data.assumingMemoryBound(to: UInt8.self),
                count: Int(buffer.byteLength)
            )
        ))
        sequenceNumber &+= 1
    }

    private func decode(_ packet: RTPPacket) {
        if audioFormat == nil {
            if let formatDescription = makeFormatDescription() {
                audioFormat = .init(cmAudioFormatDescription: formatDescription)
            }
        }
        if let audioFormat {
            let buffer = AVAudioCompressedBuffer(format: audioFormat, packetCapacity: 1, maximumPacketSize: packet.payload.count)
            packet.copyBytes(to: buffer)
            delegate?.packetizer(self, didOutput: buffer, when: timestamp.convert(packet.timestamp))
        }
    }

    package func makeFormatDescription() -> CMFormatDescription? {
        var formatDescription: CMAudioFormatDescription?
        let framesPerPacket = AVAudioFrameCount(kRTPOpusPacketizer_sampleRate * 0.02)
        var audioStreamBasicDescription = AudioStreamBasicDescription(
            mSampleRate: kRTPOpusPacketizer_sampleRate,
            mFormatID: kAudioFormatOpus,
            mFormatFlags: 0,
            mBytesPerPacket: 0,
            mFramesPerPacket: framesPerPacket,
            mBytesPerFrame: 0,
            mChannelsPerFrame: formatParameter.stereo == true ? 2 : 1,
            mBitsPerChannel: 0,
            mReserved: 0
        )
        guard CMAudioFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            asbd: &audioStreamBasicDescription,
            layoutSize: 0,
            layout: nil,
            magicCookieSize: 0,
            magicCookie: nil,
            extensions: nil,
            formatDescriptionOut: &formatDescription
        ) == noErr else {
            return nil
        }
        return formatDescription
    }
}

extension RTPOpusPacketizer: RTPJitterBufferDelegate {
    // MARK: RTPJitterBufferDelegate
    func jitterBuffer(_ buffer: RTPJitterBuffer<RTPOpusPacketizer<T>>, sequenced: RTPPacket) {
        decode(sequenced)
    }
}
