import AVFoundation

protocol RTMPMuxerDelegate: AnyObject {
    func muxer(_ muxer: RTMPMuxer, didOutputAudio buffer: Data, withTimestamp: Double)
    func muxer(_ muxer: RTMPMuxer, didOutputVideo buffer: Data, withTimestamp: Double)
}

final class RTMPMuxer {
    static let aac: UInt8 = FLVAudioCodec.aac.rawValue << 4 | FLVSoundRate.kHz44.rawValue << 2 | FLVSoundSize
        .snd16bit.rawValue << 1 | FLVSoundType.stereo.rawValue

    weak var delegate: (any RTMPMuxerDelegate)?
    private var audioTimeStamp: CMTime = .zero
    private var videoTimeStamp: CMTime = .zero
    private let compositionTimeOffset: CMTime = .init(value: 3, timescale: 30)

    func dispose() {
        audioTimeStamp = .zero
        videoTimeStamp = .zero
    }
}

extension RTMPMuxer: AudioCodecDelegate {
    func audioCodecOutputFormat(_ format: AVAudioFormat) {
        var buffer = Data([RTMPMuxer.aac, FLVAACPacketType.seq.rawValue])
        buffer.append(contentsOf: MpegTsAudioConfig(formatDescription: format.formatDescription).bytes)
        delegate?.muxer(self, didOutputAudio: buffer, withTimestamp: 0)
    }

    func audioCodecOutputBuffer(_ buffer: AVAudioBuffer, _ presentationTimeStamp: CMTime) {
        let delta = (audioTimeStamp == .zero ? 0 : presentationTimeStamp.seconds - audioTimeStamp.seconds) *
            1000
        guard let audioBuffer = buffer as? AVAudioCompressedBuffer, delta >= 0 else {
            return
        }
        var buffer = Data([RTMPMuxer.aac, FLVAACPacketType.raw.rawValue])
        buffer.append(
            audioBuffer.data.assumingMemoryBound(to: UInt8.self),
            count: Int(audioBuffer.byteLength)
        )
        delegate?.muxer(self, didOutputAudio: buffer, withTimestamp: delta)
        audioTimeStamp = presentationTimeStamp
    }
}

extension RTMPMuxer: VideoCodecDelegate {
    func videoCodecOutputFormat(_ codec: VideoCodec, _ formatDescription: CMFormatDescription) {
        var buffer: Data
        switch codec.settings.value.format {
        case .h264:
            guard let avcC = MpegTsVideoConfigAvc.getData(formatDescription) else {
                return
            }
            buffer = Data([
                FLVFrameType.key.rawValue << 4 | FLVVideoCodec.avc.rawValue,
                FLVAVCPacketType.seq.rawValue,
                0,
                0,
                0,
            ])
            buffer.append(avcC)
        case .hevc:
            guard let hvcC = MpegTsVideoConfigHevc.getData(formatDescription) else {
                return
            }
            buffer = Data([
                0b1000_0000 | FLVFrameType.key.rawValue << 4 | FLVVideoPacketType.sequenceStart.rawValue,
                0x68,
                0x76,
                0x63,
                0x31,
            ])
            buffer.append(hvcC)
        }
        delegate?.muxer(self, didOutputVideo: buffer, withTimestamp: 0)
    }

    func videoCodecOutputSampleBuffer(_ codec: VideoCodec, _ sampleBuffer: CMSampleBuffer) {
        let decodeTimeStamp = sampleBuffer.decodeTimeStamp.isValid ? sampleBuffer
            .decodeTimeStamp : sampleBuffer.presentationTimeStamp
        let compositionTime = getCompositionTime(sampleBuffer)
        let delta = (videoTimeStamp == .zero ? .zero : decodeTimeStamp - videoTimeStamp).seconds * 1000
        guard let data = sampleBuffer.dataBuffer?.data, delta >= 0 else {
            return
        }
        var buffer: Data
        let frameType = sampleBuffer.isSync ? FLVFrameType.key.rawValue : FLVFrameType.inter.rawValue
        switch codec.settings.value.format {
        case .h264:
            buffer = Data([
                (frameType << 4) | FLVVideoCodec.avc.rawValue,
                FLVAVCPacketType.nal.rawValue,
            ])
        case .hevc:
            buffer = Data([
                0b1000_0000 | (frameType << 4) | FLVVideoPacketType.codedFrames.rawValue,
                0x68,
                0x76,
                0x63,
                0x31,
            ])
        }
        buffer.append(contentsOf: compositionTime.bigEndian.data[1 ..< 4])
        buffer.append(data)
        delegate?.muxer(self, didOutputVideo: buffer, withTimestamp: delta)
        videoTimeStamp = decodeTimeStamp
    }

    private func getCompositionTime(_ sampleBuffer: CMSampleBuffer) -> Int32 {
        guard sampleBuffer.decodeTimeStamp.isValid,
              sampleBuffer.decodeTimeStamp != sampleBuffer.presentationTimeStamp
        else {
            return 0
        }
        return Int32((sampleBuffer.presentationTimeStamp - videoTimeStamp + compositionTimeOffset)
            .seconds * 1000)
    }
}
