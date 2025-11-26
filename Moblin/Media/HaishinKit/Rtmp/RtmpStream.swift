import AVFoundation

let extendedVideoHeader: UInt8 = 0b1000_0000

private func calcVideoCompositionTime(_ sampleBuffer: CMSampleBuffer) -> Int32 {
    let decodeTimeStamp = sampleBuffer.decodeTimeStamp
    guard decodeTimeStamp.isValid else {
        return 0
    }
    let presentationTimeStamp = sampleBuffer.presentationTimeStamp
    return Int32((presentationTimeStamp.seconds - decodeTimeStamp.seconds) * 1000)
}

private func makeVideoHeader(_ frameType: FlvFrameType,
                             _ fourCc: FlvVideoFourCC,
                             _ avcPacketType: FlvAvcPacketType, // Not part of FLV?
                             _ videoPacketType: FlvVideoPacketType) -> Data
{
    let writer = ByteWriter()
    if fourCc == .avc1 {
        writer.writeUInt8((frameType.rawValue << 4) | FlvVideoCodec.avc.rawValue)
        writer.writeUInt8(avcPacketType.rawValue)
    } else {
        writer.writeUInt8(extendedVideoHeader | (frameType.rawValue << 4) | videoPacketType.rawValue)
        writer.writeUInt32(fourCc.rawValue)
    }
    return writer.data
}

private func makeAvcVideoTagHeader(_ frameType: FlvFrameType, _ packetType: FlvAvcPacketType) -> Data {
    return makeVideoHeader(frameType, .avc1, packetType, .sequenceStart)
}

private func makeHevcExtendedTagHeader(_ frameType: FlvFrameType, _ packetType: FlvVideoPacketType) -> Data {
    return makeVideoHeader(frameType, .hevc, .nal, packetType)
}

protocol RtmpStreamDelegate: AnyObject {
    func rtmpStreamStatus(_ rtmpStream: RtmpStream, code: String)
    func rtmpStreamConnected(_ rtmpStream: RtmpStream)
}

enum RtmpStreamCode: String {
    case publishStart = "NetStream.Publish.Start"
}

private let aac = FlvAudioCodec.aac.rawValue << 4
    | FlvSoundRate.kHz44.rawValue << 2
    | FlvSoundSize.snd16bit.rawValue << 1
    | FlvSoundType.stereo.rawValue

private let opus = FlvAudioCodec.exHeader.rawValue << 4
    | FlvOpusPacketType.sequenceStart.rawValue

private enum State {
    case initialized
    case open
    case publishing
}

class RtmpStream {
    let info = RtmpStreamInfo()
    var streamId: UInt32 = 0
    private var state: State = .initialized
    private var startedAt = Date()
    private var audioChunkType: RtmpChunkType = .zero
    private var videoChunkType: RtmpChunkType = .zero
    private var dataTimeStamps: [String: Date] = [:]
    private let connection: RtmpConnection
    private var streamKey = ""
    private var url: String = ""
    let name: String
    private let connectTimer = SimpleTimer(queue: processorControlQueue)

    // Outbound
    private var baseTimeStamp = -1.0
    private var audioTimeStampDelta = 0.0
    private var videoTimeStampDelta = 0.0
    private var prevRebasedAudioTimeStamp: Double?
    private var prevRebasedVideoTimeStamp: Double?
    private let processor: Processor
    weak var delegate: RtmpStreamDelegate?

    init(name: String, processor: Processor, delegate: RtmpStreamDelegate) {
        self.name = name
        self.processor = processor
        self.delegate = delegate
        connection = RtmpConnection(name: name)
        connection.stream = self
    }

    func setUrl(_ url: String) {
        streamKey = makeRtmpStreamKey(url: url)
        self.url = makeRtmpUri(url: url)
    }

    func connect() {
        processorControlQueue.async {
            self.connectInternal()
        }
    }

    func disconnect() {
        processorControlQueue.async {
            self.disconnectInternal()
        }
    }

    func reconnectSoon() {
        processorControlQueue.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.connectInternal()
        }
    }

    func onTimeout() {
        info.onTimeout()
    }

    func closeInternal() {
        setState(state: .initialized)
        stopConnectTimer()
        processor.stopEncoding(self)
    }

    func onInternal(data: AsObject) {
        guard let code = data["code"] as? String else {
            return
        }
        delegate?.rtmpStreamStatus(self, code: code)
        switch code {
        case RtmpConnectionCode.connectSuccess.rawValue:
            setState(state: .initialized)
            sendReleaseStream()
            sendFCPublish()
            sendCreateStream()
        case RtmpStreamCode.publishStart.rawValue:
            if state != .initialized {
                setState(state: .publishing)
            }
        default:
            break
        }
    }

    private func setState(state: State) {
        guard self.state != state else {
            return
        }
        let oldState = self.state
        self.state = state
        logger.info("rtmp: \(name): Stream state \(oldState) -> \(state)")
        if oldState == .publishing {
            sendFCUnpublish()
            sendDeleteStream()
            closeStream()
            processor.stopEncoding(self)
        }
        switch state {
        case .open:
            handleStateChangeToOpen()
        case .publishing:
            handleStateChangeToPublishing()
        default:
            break
        }
    }

    private func connectInternal() {
        startConnectTimer()
        connection.connect(url)
    }

    private func disconnectInternal() {
        setState(state: .initialized)
        processor.stopEncoding(self)
        stopConnectTimer()
        connection.disconnect()
    }

    private func startConnectTimer() {
        connectTimer.startSingleShot(timeout: 20) { [weak self] in
            guard let self else {
                return
            }
            logger.info("rtmp: \(name): Connect timeout")
            connection.socket.close(isDisconnected: true)
        }
    }

    private func stopConnectTimer() {
        connectTimer.stop()
    }

    private func send(handlerName: String, arguments: Any?...) {
        guard state == .publishing else {
            return
        }
        let dataWasSent = dataTimeStamps[handlerName] != nil
        let timestmap = dataWasSent ?
            UInt32((dataTimeStamps[handlerName]?.timeIntervalSinceNow ?? 0) * -1000) :
            UInt32(startedAt.timeIntervalSinceNow * -1000)
        let chunk = RtmpChunk(
            type: dataWasSent ? RtmpChunkType.one : RtmpChunkType.zero,
            chunkStreamId: RtmpChunk.ChunkStreamId.data.rawValue,
            message: RtmpDataMessage(
                streamId: streamId,
                dataType: .amf0Data,
                timestamp: timestmap,
                handlerName: handlerName,
                arguments: arguments
            )
        )
        let length = connection.socket.write(chunk: chunk)
        dataTimeStamps[handlerName] = .init()
        info.byteCount.mutate { $0 += Int64(length) }
    }

    private func createOnMetaData() -> AsObject {
        let audioEncoder = processor.getAudioEncoder()
        let videoEncoder = processor.getVideoEncoder()
        var metadata: [String: Any] = [:]
        let settings = videoEncoder.settings.value
        metadata["width"] = settings.videoSize.width
        metadata["height"] = settings.videoSize.height
        metadata["framerate"] = processor.getFps()
        switch settings.format {
        case .h264:
            metadata["videocodecid"] = FlvVideoCodec.avc.rawValue
        case .hevc:
            metadata["videocodecid"] = FlvVideoFourCC.hevc.rawValue
        }
        metadata["videodatarate"] = settings.bitRate / 1000
        metadata["audiocodecid"] = FlvAudioCodec.aac.rawValue
        metadata["audiodatarate"] = audioEncoder.getBitrate() / 1000
        if let sampleRate = audioEncoder.getSampleRate() {
            metadata["audiosamplerate"] = sampleRate
        }
        return metadata
    }

    private func handleStateChangeToOpen() {
        info.clear()
        _ = connection.socket.write(chunk: RtmpChunk(message: RtmpCommandMessage(
            streamId: streamId,
            transactionId: connection.getNextTransactionId(),
            commandType: .amf0Command,
            commandName: .publish,
            commandObject: nil,
            arguments: [streamKey, "live"]
        )))
        startedAt = .init()
        baseTimeStamp = -1.0
        audioTimeStampDelta = 0.0
        videoTimeStampDelta = 0.0
        prevRebasedAudioTimeStamp = nil
        prevRebasedVideoTimeStamp = nil
        videoChunkType = .zero
        audioChunkType = .zero
        dataTimeStamps.removeAll()
    }

    private func handleStateChangeToPublishing() {
        send(handlerName: "@setDataFrame", arguments: "onMetaData", createOnMetaData())
        stopConnectTimer()
        delegate?.rtmpStreamConnected(self)
        processor.startEncoding(self)
    }

    private func sendCreateStream() {
        connection.call(.createStream, arguments: []) { data in
            guard let id = data[0] as? Double, id >= 0, id <= Double(UInt32.max) else {
                return
            }
            self.streamId = UInt32(id)
            self.setState(state: .open)
        }
    }

    private func sendReleaseStream() {
        connection.call(.releaseStream, arguments: [streamKey])
    }

    private func sendFCPublish() {
        connection.call(.fcPublish, arguments: [streamKey])
    }

    private func sendFCUnpublish() {
        connection.call(.fcUnpublish, arguments: [streamKey])
    }

    private func sendDeleteStream() {
        _ = connection.socket.write(chunk: RtmpChunk(message: RtmpCommandMessage(
            streamId: streamId,
            transactionId: 0,
            commandType: .amf0Command,
            commandName: .deleteStream,
            commandObject: nil,
            arguments: [streamId]
        )))
    }

    private func closeStream() {
        _ = connection.socket.write(chunk: RtmpChunk(
            type: .zero,
            chunkStreamId: RtmpChunk.ChunkStreamId.command.rawValue,
            message: RtmpCommandMessage(
                streamId: 0,
                transactionId: 0,
                commandType: .amf0Command,
                commandName: .closeStream,
                commandObject: nil,
                arguments: [streamId]
            )
        ))
    }

    private func handleEncodedAudioBuffer(_ buffer: Data, _ timestamp: UInt32) {
        guard state == .publishing else {
            return
        }
        let length = connection.socket.write(chunk: RtmpChunk(
            type: audioChunkType,
            chunkStreamId: FlvTagType.audio.streamId,
            message: RtmpAudioMessage(streamId: streamId, timestamp: timestamp, payload: buffer)
        ))
        audioChunkType = .one
        info.byteCount.mutate { $0 += Int64(length) }
    }

    private func handleEncodedVideoBuffer(_ buffer: Data, _ timestamp: UInt32) {
        guard state == .publishing else {
            return
        }
        let length = connection.socket.write(chunk: RtmpChunk(
            type: videoChunkType,
            chunkStreamId: FlvTagType.video.streamId,
            message: RtmpVideoMessage(streamId: streamId, timestamp: timestamp, payload: buffer)
        ))
        videoChunkType = .one
        info.byteCount.mutate { $0 += Int64(length) }
    }

    private func audioEncoderOutputFormatInner(_ format: AVAudioFormat) {
        guard let audioStreamBasicDescription = format.formatDescription.audioStreamBasicDescription else {
            return
        }
        let writer = ByteWriter()
        switch audioStreamBasicDescription.mFormatID {
        case kAudioFormatOpus:
            writer.writeUInt8(opus)
            writer.writeUTF8Bytes("Opus")
            writer.writeUTF8Bytes("OpusHead")
            writer.writeUInt8(1)
            writer.writeUInt8(UInt8(audioStreamBasicDescription.mChannelsPerFrame))
            writer.writeUInt16(0)
            writer.writeUInt32(UInt32(audioStreamBasicDescription.mSampleRate))
            writer.writeUInt16(0)
            writer.writeUInt8(0)
        default:
            writer.writeUInt8(aac)
            writer.writeUInt8(FlvAacPacketType.seq.rawValue)
            writer.writeBytes(MpegTsAudioConfig(formatDescription: format.formatDescription).encode())
        }
        handleEncodedAudioBuffer(writer.data, 0)
    }

    private func audioEncoderOutputBufferInner(_ audioBuffer: AVAudioCompressedBuffer,
                                               _ presentationTimeStamp: CMTime)
    {
        guard let rebasedTimestamp = rebaseTimeStamp(timestamp: presentationTimeStamp.seconds) else {
            logger.info("rtmp: \(name): Dropping audio buffer. Failed to rebase timestamp.")
            return
        }
        var delta = 0.0
        if let prevRebasedAudioTimeStamp {
            delta = (rebasedTimestamp - prevRebasedAudioTimeStamp) * 1000
        }
        guard delta >= 0 else {
            logger.info("rtmp: \(name): Dropping audio buffer (delta: \(delta))")
            return
        }
        var buffer: Data
        switch audioBuffer.format.formatDescription.audioStreamBasicDescription?.mFormatID {
        case kAudioFormatOpus:
            buffer = Data([FlvAudioCodec.exHeader.rawValue << 4 | FlvOpusPacketType.codedFrames.rawValue])
            buffer += "Opus".utf8Data
        default:
            buffer = Data([aac, FlvAacPacketType.raw.rawValue])
        }
        buffer.append(audioBuffer.data.assumingMemoryBound(to: UInt8.self), count: Int(audioBuffer.byteLength))
        prevRebasedAudioTimeStamp = rebasedTimestamp
        handleEncodedAudioBuffer(buffer, UInt32(audioTimeStampDelta))
        audioTimeStampDelta -= floor(audioTimeStampDelta)
        audioTimeStampDelta += delta
    }

    private func videoEncoderOutputFormatInner(
        _ format: VideoEncoderSettings.Format,
        _ formatDescription: CMFormatDescription
    ) {
        var buffer: Data
        switch format {
        case .h264:
            guard let avcC = MpegTsVideoConfigAvc.getAvcC(formatDescription) else {
                return
            }
            buffer = makeAvcVideoTagHeader(.key, .seq)
            buffer += Data([0, 0, 0])
            buffer += avcC
        case .hevc:
            guard let hvcC = MpegTsVideoConfigHevc.getHvcC(formatDescription) else {
                return
            }
            buffer = makeHevcExtendedTagHeader(.key, .sequenceStart)
            buffer += hvcC
        }
        handleEncodedVideoBuffer(buffer, 0)
    }

    private func videoEncoderOutputSampleBufferInner(_ format: VideoEncoderSettings.Format,
                                                     _ sampleBuffer: CMSampleBuffer)
    {
        let decodeTimeStamp: Double
        if sampleBuffer.decodeTimeStamp.isValid {
            decodeTimeStamp = sampleBuffer.decodeTimeStamp.seconds
        } else {
            decodeTimeStamp = sampleBuffer.presentationTimeStamp.seconds
        }
        guard let rebasedTimestamp = rebaseTimeStamp(timestamp: decodeTimeStamp) else {
            return
        }
        var delta = 0.0
        if let prevRebasedVideoTimeStamp {
            delta = (rebasedTimestamp - prevRebasedVideoTimeStamp) * 1000
        }
        guard let data = sampleBuffer.dataBuffer?.data, delta >= 0 else {
            logger.info("rtmp: \(name): Dropping video buffer (delta: \(delta))")
            return
        }
        var buffer: Data
        let frameType = sampleBuffer.getIsSync() ? FlvFrameType.key : FlvFrameType.inter
        switch format {
        case .h264:
            buffer = makeAvcVideoTagHeader(frameType, .nal)
        case .hevc:
            buffer = makeHevcExtendedTagHeader(frameType, .codedFrames)
        }
        let compositionTime = calcVideoCompositionTime(sampleBuffer)
        buffer.append(contentsOf: compositionTime.bigEndian.data[1 ..< 4])
        buffer.append(data)
        prevRebasedVideoTimeStamp = rebasedTimestamp
        handleEncodedVideoBuffer(buffer, UInt32(videoTimeStampDelta))
        videoTimeStampDelta -= floor(videoTimeStampDelta)
        videoTimeStampDelta += delta
    }

    private func rebaseTimeStamp(timestamp: Double) -> Double? {
        if baseTimeStamp == -1.0 {
            baseTimeStamp = timestamp
        }
        let timestamp = timestamp - baseTimeStamp
        if timestamp >= 0 {
            return timestamp
        } else {
            return nil
        }
    }
}

extension RtmpStream: AudioEncoderDelegate {
    func audioEncoderOutputFormat(_ format: AVAudioFormat) {
        processorControlQueue.async {
            self.audioEncoderOutputFormatInner(format)
        }
    }

    func audioEncoderOutputBuffer(_ buffer: AVAudioCompressedBuffer, _ presentationTimeStamp: CMTime) {
        processorControlQueue.async {
            self.audioEncoderOutputBufferInner(buffer, presentationTimeStamp)
        }
    }
}

extension RtmpStream: VideoEncoderDelegate {
    func videoEncoderOutputFormat(_ encoder: VideoEncoder, _ formatDescription: CMFormatDescription) {
        let format = encoder.settings.value.format
        processorControlQueue.async {
            self.videoEncoderOutputFormatInner(format, formatDescription)
        }
    }

    func videoEncoderOutputSampleBuffer(_ codec: VideoEncoder,
                                        _ sampleBuffer: CMSampleBuffer,
                                        _: CMTime)
    {
        let format = codec.settings.value.format
        processorControlQueue.async {
            self.videoEncoderOutputSampleBufferInner(format, sampleBuffer)
        }
    }
}
