import AVFoundation

final class RtmpAudioMessage: RtmpMessage {
    private(set) var codec: FlvAudioCodec = .unknown
    private(set) var soundRate: FlvSoundRate = .kHz44
    private(set) var soundSize: FlvSoundSize = .snd8bit
    private(set) var soundType: FlvSoundType = .stereo

    init() {
        super.init(type: .audio)
    }

    init(streamId: UInt32, timestamp: UInt32, payload: Data) {
        super.init(type: .audio)
        self.streamId = streamId
        self.timestamp = timestamp
        encoded = payload
    }

    override func execute(_ connection: RtmpConnection, type: RTMPChunkType) {
        guard let stream = connection.streams.first(where: { $0.id == streamId }) else {
            return
        }
        stream.info.byteCount.mutate { $0 += Int64(encoded.count) }
        guard codec.isSupported else {
            return
        }
        var duration = Int64(timestamp)
        switch type {
        case .zero:
            if stream.audioTimestampZero == -1 {
                stream.audioTimestampZero = Double(timestamp)
            }
            duration -= Int64(stream.audioTimeStamp)
            stream.audioTimeStamp = Double(timestamp) - stream.audioTimestampZero
        default:
            stream.audioTimeStamp += Double(timestamp)
        }
        switch encoded[1] {
        case FlvAacPacketType.seq.rawValue:
            let config = MpegTsAudioConfig(bytes: [UInt8](encoded[codec.headerSize ..< encoded.count]))
            stream.mixer.audio.encoder.settings.format = .pcm
            stream.mixer.audio.encoder.inSourceFormat = config?.audioStreamBasicDescription()
        case FlvAacPacketType.raw.rawValue:
            if stream.mixer.audio.encoder.inSourceFormat == nil {
                stream.mixer.audio.encoder.settings.format = .pcm
                stream.mixer.audio.encoder.inSourceFormat = makeAudioStreamBasicDescription()
            }
            if let audioBuffer = makeAudioBuffer(stream) {
                stream.mixer.audio.encoder.appendAudioBuffer(
                    audioBuffer,
                    presentationTimeStamp: CMTime(
                        seconds: stream.audioTimeStamp / 1000,
                        preferredTimescale: 1000
                    )
                )
            }
        default:
            break
        }
    }

    override var encoded: Data {
        get {
            super.encoded
        }
        set {
            if super.encoded == newValue {
                return
            }
            super.encoded = newValue
            if length == newValue.count && !newValue.isEmpty {
                guard let codec = FlvAudioCodec(rawValue: newValue[0] >> 4),
                      let soundRate = FlvSoundRate(rawValue: (newValue[0] & 0b0000_1100) >> 2),
                      let soundSize = FlvSoundSize(rawValue: (newValue[0] & 0b0000_0010) >> 1),
                      let soundType = FlvSoundType(rawValue: newValue[0] & 0b0000_0001)
                else {
                    return
                }
                self.codec = codec
                self.soundRate = soundRate
                self.soundSize = soundSize
                self.soundType = soundType
            }
        }
    }

    private func makeAudioBuffer(_ stream: RtmpStream) -> AVAudioBuffer? {
        return encoded.withUnsafeMutableBytes { (buffer: UnsafeMutableRawBufferPointer) -> AVAudioBuffer? in
            guard let baseAddress = buffer.baseAddress,
                  let buffer = stream.mixer.audio.encoder.makeInputBuffer() as? AVAudioCompressedBuffer
            else {
                return nil
            }
            let byteCount = encoded.count - codec.headerSize
            buffer.packetDescriptions?.pointee = AudioStreamPacketDescription(
                mStartOffset: 0,
                mVariableFramesInPacket: 0,
                mDataByteSize: UInt32(byteCount)
            )
            buffer.packetCount = 1
            buffer.byteLength = UInt32(byteCount)
            buffer.data.copyMemory(from: baseAddress.advanced(by: codec.headerSize), byteCount: byteCount)
            return buffer
        }
    }

    private func makeAudioStreamBasicDescription() -> AudioStreamBasicDescription? {
        return codec.audioStreamBasicDescription(soundRate, size: soundSize, type: soundType)
    }
}
