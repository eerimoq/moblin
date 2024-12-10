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

    override func execute(_ connection: RtmpConnection, type: RTMPChunkType) {
        guard let stream = connection.streams.first(where: { $0.id == streamId }) else {
            return
        }
        stream.info.byteCount.mutate { $0 += Int64(encoded.count) }
        guard FlvTagType.video.headerSize <= encoded.count else {
            return
        }
        if (encoded[0] & 0b1000_0000) == 0 {
            guard encoded[0] & 0b0111_0000 >> 4 == FlvVideoCodec.avc.rawValue else {
                return
            }
            switch encoded[1] {
            case FlvAvcPacketType.seq.rawValue:
                makeFormatDescription(stream, format: .h264)
            case FlvAvcPacketType.nal.rawValue:
                if let sampleBuffer = makeSampleBuffer(stream, type: type, offset: 0) {
                    stream.mixer.video.encoder.decodeSampleBuffer(sampleBuffer)
                }
            default:
                break
            }
        } else {
            // IsExHeader for Enhancing RTMP, FLV
            guard encoded[1] == 0x68 && encoded[2] == 0x76 && encoded[3] == 0x63 && encoded[4] == 0x31 else {
                return
            }
            switch encoded[0] & 0b0000_1111 {
            case FlvVideoPacketType.sequenceStart.rawValue:
                makeFormatDescription(stream, format: .hevc)
            case FlvVideoPacketType.codedFrames.rawValue:
                if let sampleBuffer = makeSampleBuffer(stream, type: type, offset: 3) {
                    stream.mixer.video.encoder.decodeSampleBuffer(sampleBuffer)
                }
            default:
                break
            }
        }
    }

    private func makeSampleBuffer(_ stream: RtmpStream, type: RTMPChunkType,
                                  offset: Int = 0) -> CMSampleBuffer?
    {
        // compositionTime -> SI24
        var compositionTime = Int32(data: [0] + encoded[2 + offset ..< 5 + offset]).bigEndian
        compositionTime <<= 8
        compositionTime /= 256
        var duration = Int64(timestamp)
        switch type {
        case .zero:
            if stream.videoTimestampZero == -1 {
                stream.videoTimestampZero = Double(timestamp)
            }
            duration -= Int64(stream.videoTimeStamp)
            stream.videoTimeStamp = Double(timestamp) - stream.videoTimestampZero
        default:
            stream.videoTimeStamp += Double(timestamp)
        }
        var timing = CMSampleTimingInfo(
            duration: CMTimeMake(value: duration, timescale: 1000),
            presentationTimeStamp: CMTimeMake(
                value: Int64(stream.videoTimeStamp) + Int64(compositionTime),
                timescale: 1000
            ),
            decodeTimeStamp: compositionTime == 0 ? .invalid : CMTimeMake(
                value: Int64(stream.videoTimeStamp),
                timescale: 1000
            )
        )
        let blockBuffer = encoded.makeBlockBuffer(advancedBy: FlvTagType.video.headerSize + offset)
        var sampleBuffer: CMSampleBuffer?
        var sampleSize = blockBuffer?.dataLength ?? 0
        guard CMSampleBufferCreate(
            allocator: kCFAllocatorDefault,
            dataBuffer: blockBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: stream.mixer.video.formatDescription,
            sampleCount: 1,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleSizeEntryCount: 1,
            sampleSizeArray: &sampleSize,
            sampleBufferOut: &sampleBuffer
        ) == noErr else {
            return nil
        }
        sampleBuffer?.isSync = encoded[0] >> 4 & 0b0111 == FlvFrameType.key.rawValue
        return sampleBuffer
    }

    private func makeFormatDescription(_ stream: RtmpStream, format: VideoCodecSettings.Format) {
        var status = noErr
        switch format {
        case .h264:
            var config = MpegTsVideoConfigAvc()
            config.data = encoded.subdata(in: FlvTagType.video.headerSize ..< encoded.count)
            status = config.makeFormatDescription(&stream.mixer.video.formatDescription)
        case .hevc:
            var config = MpegTsVideoConfigHevc()
            config.data = encoded.subdata(in: FlvTagType.video.headerSize ..< encoded.count)
            status = config.makeFormatDescription(&stream.mixer.video.formatDescription)
        }
        if status == noErr {
            stream.dispatch(.rtmpStatus, data: RtmpStreamCode.videoDimensionChange.eventData())
        }
    }
}
