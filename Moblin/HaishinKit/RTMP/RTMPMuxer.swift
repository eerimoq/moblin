import AVFoundation

protocol RTMPMuxerDelegate: AnyObject {
    func muxer(_ muxer: RTMPMuxer, didOutputAudio buffer: Data, withTimestamp: Double)
    func muxer(_ muxer: RTMPMuxer, didOutputVideo buffer: Data, withTimestamp: Double)
}

final class RTMPMuxer {
    static let aac = FLVAudioCodec.aac.rawValue << 4 | FLVSoundRate.kHz44.rawValue << 2 | FLVSoundSize
        .snd16bit.rawValue << 1 | FLVSoundType.stereo.rawValue

    weak var delegate: (any RTMPMuxerDelegate)?
    private var audioTimeStamp: Double = 0.0
    private var videoTimeStamp: Double = 0.0
    private let compositionTimeOffset = CMTime(value: 3, timescale: 30).seconds

    func dispose() {
        audioTimeStamp = 0.0
        videoTimeStamp = 0.0
    }
}

extension RTMPMuxer: AudioCodecDelegate {
    func audioCodecOutputFormat(_ format: AVAudioFormat) {
        var buffer = Data([RTMPMuxer.aac, FLVAACPacketType.seq.rawValue])
        buffer.append(contentsOf: MpegTsAudioConfig(formatDescription: format.formatDescription).bytes)
        delegate?.muxer(self, didOutputAudio: buffer, withTimestamp: 0)
    }

    func audioCodecOutputBuffer(_ buffer: AVAudioBuffer, _ presentationTimeStamp: CMTime) {
        let delta = (audioTimeStamp == 0.0 ? 0.0 : presentationTimeStamp.seconds - audioTimeStamp) * 1000
        guard let audioBuffer = buffer as? AVAudioCompressedBuffer, delta >= 0 else {
            return
        }
        var buffer = Data([RTMPMuxer.aac, FLVAACPacketType.raw.rawValue])
        buffer.append(
            audioBuffer.data.assumingMemoryBound(to: UInt8.self),
            count: Int(audioBuffer.byteLength)
        )
        delegate?.muxer(self, didOutputAudio: buffer, withTimestamp: delta)
        audioTimeStamp = presentationTimeStamp.seconds
    }
}

private let extendedVideoHeader: UInt8 = 0b1000_0000

private func makeAvcVideoTagHeader(_ frameType: FLVFrameType, _ packetType: FLVAVCPacketType) -> Data {
    return Data([
        (frameType.rawValue << 4) | FLVVideoCodec.avc.rawValue,
        packetType.rawValue,
    ])
}

private func makeHevcExtendedTagHeader(_ frameType: FLVFrameType, _ packetType: FLVVideoPacketType) -> Data {
    return Data([
        extendedVideoHeader | (frameType.rawValue << 4) | packetType.rawValue,
        Character("h").asciiValue!,
        Character("v").asciiValue!,
        Character("c").asciiValue!,
        Character("1").asciiValue!,
    ])
}

extension RTMPMuxer: VideoCodecDelegate {
    func videoCodecOutputFormat(_ codec: VideoCodec, _ formatDescription: CMFormatDescription) {
        var buffer: Data
        switch codec.settings.value.format {
        case .h264:
            guard let avcC = MpegTsVideoConfigAvc.getData(formatDescription) else {
                return
            }
            buffer = makeAvcVideoTagHeader(.key, .seq)
            buffer += Data([0, 0, 0])
            buffer += avcC
        case .hevc:
            guard let hvcC = MpegTsVideoConfigHevc.getData(formatDescription) else {
                return
            }
            buffer = makeHevcExtendedTagHeader(.key, .sequenceStart)
            buffer += hvcC
        }
        delegate?.muxer(self, didOutputVideo: buffer, withTimestamp: 0)
    }

    func videoCodecOutputSampleBuffer(_ codec: VideoCodec, _ sampleBuffer: CMSampleBuffer) {
        let decodeTimeStamp = sampleBuffer.decodeTimeStamp.isValid ? sampleBuffer
            .decodeTimeStamp : sampleBuffer.presentationTimeStamp
        let compositionTime = getCompositionTime(sampleBuffer)
        let delta = (videoTimeStamp == 0.0 ? 0.0 : decodeTimeStamp.seconds - videoTimeStamp) * 1000
        guard let data = sampleBuffer.dataBuffer?.data, delta >= 0 else {
            return
        }
        var buffer: Data
        let frameType = sampleBuffer.isSync ? FLVFrameType.key : FLVFrameType.inter
        switch codec.settings.value.format {
        case .h264:
            buffer = makeAvcVideoTagHeader(frameType, .nal)
        case .hevc:
            buffer = makeHevcExtendedTagHeader(frameType, .codedFrames)
        }
        buffer.append(contentsOf: compositionTime.bigEndian.data[1 ..< 4])
        buffer.append(data)
        delegate?.muxer(self, didOutputVideo: buffer, withTimestamp: delta)
        videoTimeStamp = decodeTimeStamp.seconds
    }

    private func getCompositionTime(_ sampleBuffer: CMSampleBuffer) -> Int32 {
        let presentationTimeStamp = sampleBuffer.presentationTimeStamp
        let decodeTimeStamp = sampleBuffer.decodeTimeStamp
        guard decodeTimeStamp.isValid, decodeTimeStamp != presentationTimeStamp else {
            return 0
        }
        return Int32((presentationTimeStamp.seconds - videoTimeStamp + compositionTimeOffset) * 1000)
    }
}
