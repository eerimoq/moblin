@preconcurrency import AVFoundation

struct RtmpTimestamps {
    private struct Track {
        private var previous: Double?
        private var fraction = 0.0

        mutating func next(_ timestamp: Double) -> UInt32? {
            var delta = 0.0
            if let previous {
                delta = (timestamp - previous) * 1000
            }
            guard delta >= 0 else {
                return nil
            }
            previous = timestamp
            fraction += delta
            let timestampDelta = UInt32(fraction)
            fraction -= floor(fraction)
            return timestampDelta
        }
    }

    private var base: Double?
    private var audioTrack = Track()
    private var videoTrack = Track()

    mutating func audio(_ timestamp: Double) -> UInt32? {
        guard let timestamp = rebase(timestamp) else {
            return nil
        }
        return audioTrack.next(timestamp)
    }

    mutating func video(_ timestamp: Double) -> UInt32? {
        guard let timestamp = rebase(timestamp) else {
            return nil
        }
        return videoTrack.next(timestamp)
    }

    private mutating func rebase(_ timestamp: Double) -> Double? {
        let base = base ?? timestamp
        self.base = base
        let timestamp = timestamp - base
        guard timestamp >= 0 else {
            return nil
        }
        return timestamp
    }
}

private let aac = FlvAudioCodec.aac.rawValue << 4
    | FlvSoundRate.kHz44.rawValue << 2
    | FlvSoundSize.snd16bit.rawValue << 1
    | FlvSoundType.stereo.rawValue

private let opus = FlvAudioCodec.exHeader.rawValue << 4
    | FlvOpusPacketType.sequenceStart.rawValue

func makeRtmpAudioSequenceHeader(_ format: AVAudioFormat) -> Data? {
    guard let description = format.formatDescription.audioStreamBasicDescription else {
        return nil
    }
    let writer = ByteWriter()
    switch description.mFormatID {
    case kAudioFormatOpus:
        writer.writeUInt8(opus)
        writer.writeUTF8Bytes("Opus")
        writer.writeUTF8Bytes("OpusHead")
        writer.writeUInt8(1)
        writer.writeUInt8(UInt8(description.mChannelsPerFrame))
        writer.writeUInt16(0)
        writer.writeUInt32(UInt32(description.mSampleRate))
        writer.writeUInt16(0)
        writer.writeUInt8(0)
    default:
        writer.writeUInt8(aac)
        writer.writeUInt8(FlvAacPacketType.seq.rawValue)
        writer.writeBytes(MpegTsAudioConfig(formatDescription: format.formatDescription).encode())
    }
    return writer.data
}

func makeRtmpAudioFrame(_ audioBuffer: AVAudioCompressedBuffer) -> Data {
    var buffer: Data
    switch audioBuffer.format.formatDescription.audioStreamBasicDescription?.mFormatID {
    case kAudioFormatOpus:
        buffer = Data([FlvAudioCodec.exHeader.rawValue << 4 | FlvOpusPacketType.codedFrames.rawValue])
        buffer += "Opus".utf8Data
    default:
        buffer = Data([aac, FlvAacPacketType.raw.rawValue])
    }
    buffer.append(audioBuffer.data.assumingMemoryBound(to: UInt8.self), count: Int(audioBuffer.byteLength))
    return buffer
}

private func makeAvcVideoTagHeader(_ frameType: FlvFrameType, _ packetType: FlvAvcPacketType) -> Data {
    Data([(frameType.rawValue << 4) | FlvVideoCodec.avc.rawValue, packetType.rawValue])
}

private func makeHevcVideoTagHeader(_ frameType: FlvFrameType, _ packetType: FlvVideoPacketType) -> Data {
    let writer = ByteWriter()
    writer.writeUInt8(extendedVideoHeader | (frameType.rawValue << 4) | packetType.rawValue)
    writer.writeUInt32(FlvVideoFourCC.hevc.rawValue)
    return writer.data
}

func makeRtmpVideoSequenceHeader(_ format: VideoEncoderSettings.Format,
                                 _ formatDescription: CMFormatDescription) -> Data?
{
    switch format {
    case .h264:
        guard let avcC = MpegTsVideoConfigAvc.getAvcC(formatDescription) else {
            return nil
        }
        return makeAvcVideoTagHeader(.key, .seq) + Data([0, 0, 0]) + avcC
    case .hevc:
        guard let hvcC = MpegTsVideoConfigHevc.getHvcC(formatDescription) else {
            return nil
        }
        return makeHevcVideoTagHeader(.key, .sequenceStart) + hvcC
    }
}

func makeRtmpVideoFrame(_ format: VideoEncoderSettings.Format,
                        _ sampleBuffer: CMSampleBuffer,
                        _ data: Data) -> Data
{
    let frameType = sampleBuffer.getIsSync() ? FlvFrameType.key : FlvFrameType.inter
    var buffer: Data = switch format {
    case .h264:
        makeAvcVideoTagHeader(frameType, .nal)
    case .hevc:
        makeHevcVideoTagHeader(frameType, .codedFrames)
    }
    var compositionTime: Int32 = 0
    if sampleBuffer.decodeTimeStamp.isValid {
        compositionTime = Int32((sampleBuffer.presentationTimeStamp.seconds
                - sampleBuffer.decodeTimeStamp.seconds) * 1000)
    }
    buffer.append(contentsOf: compositionTime.bigEndian.data[1 ..< 4])
    buffer.append(data)
    return buffer
}

protocol RtmpStreamDelegate: AnyObject {
    func rtmpStreamStatus(_ rtmpStream: RtmpStream, code: String)
    func rtmpStreamConnected(_ rtmpStream: RtmpStream)
}

enum RtmpStreamCode: String {
    case publishStart = "NetStream.Publish.Start"
}

private enum State {
    case initialized
    case open
    case publishing
}

class RtmpStream: @unchecked Sendable {
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
    private let connectTimer: SimpleTimer
    private let queue: DispatchQueue

    private var timestamps = RtmpTimestamps()
    private let processor: Processor
    weak let delegate: (any RtmpStreamDelegate)?

    init(name: String, processor: Processor, delegate: any RtmpStreamDelegate, queue: DispatchQueue) {
        self.name = name
        self.processor = processor
        self.delegate = delegate
        self.queue = queue
        connectTimer = SimpleTimer(queue: queue)
        connection = RtmpConnection(name: name, queue: queue)
        connection.stream = self
    }

    func setUrl(_ url: String) {
        streamKey = makeRtmpStreamKey(url: url)
        self.url = makeRtmpUri(url: url)
    }

    func connect() {
        queue.async {
            self.connectInternal()
        }
    }

    func disconnect() {
        queue.async {
            self.disconnectInternal()
        }
    }

    func reconnectSoon() {
        queue.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.connectInternal()
        }
    }

    func onTimeout() {
        info.onTimeout()
    }

    func closeInternal() {
        setState(state: .initialized)
        stopConnectTimer()
        processorPipelineQueue.async {
            self.processor.stopEncoding(self)
        }
    }

    func onInternal(data: AsObject) {
        guard case let .string(code) = data["code"] else {
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
            sendCloseStream()
            processorPipelineQueue.async {
                self.processor.stopEncoding(self)
            }
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
        processorPipelineQueue.async {
            self.processor.stopEncoding(self)
        }
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

    private func send(handlerName: String, arguments: AsValue...) {
        guard state == .publishing else {
            return
        }
        let dataWasSent = dataTimeStamps[handlerName] != nil
        let timestamp = dataWasSent ?
            UInt32(max((dataTimeStamps[handlerName]?.timeIntervalSinceNow ?? 0) * -1000, 0)) :
            UInt32(max(startedAt.timeIntervalSinceNow * -1000, 0))
        let chunk = RtmpChunk(
            type: dataWasSent ? RtmpChunkType.one : RtmpChunkType.zero,
            chunkStreamId: RtmpChunk.ChunkStreamId.data.rawValue,
            message: RtmpDataMessage(
                streamId: streamId,
                dataType: .amf0Data,
                timestamp: timestamp,
                handlerName: handlerName,
                arguments: arguments
            )
        )
        let length = connection.socket.write(chunk: chunk)
        dataTimeStamps[handlerName] = .init()
        info.bitrateStats.mutate { $0.add(bytesTransferred: length) }
    }

    private func createOnMetaData() -> AsObject {
        let audioEncoder = processor.getAudioEncoder()
        let videoEncoder = processor.getVideoEncoder()
        var metadata: AsObject = [:]
        let settings = videoEncoder.settings.value
        metadata["width"] = .number(Double(settings.videoSize.width))
        metadata["height"] = .number(Double(settings.videoSize.height))
        metadata["framerate"] = .number(processor.getFps())
        switch settings.format {
        case .h264:
            metadata["videocodecid"] = .number(Double(FlvVideoCodec.avc.rawValue))
        case .hevc:
            metadata["videocodecid"] = .number(Double(FlvVideoFourCC.hevc.rawValue))
        }
        metadata["videodatarate"] = .number(Double(settings.bitrate / 1000))
        metadata["audiocodecid"] = .number(Double(FlvAudioCodec.aac.rawValue))
        metadata["audiodatarate"] = .number(Double(audioEncoder.getBitrate() / 1000))
        if let sampleRate = audioEncoder.getSampleRate() {
            metadata["audiosamplerate"] = .number(sampleRate)
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
            arguments: [.string(streamKey), .string("live")]
        )))
        startedAt = .init()
        timestamps = RtmpTimestamps()
        videoChunkType = .zero
        audioChunkType = .zero
        dataTimeStamps.removeAll()
    }

    private func handleStateChangeToPublishing() {
        send(handlerName: "@setDataFrame",
             arguments: .string("onMetaData"), .object(createOnMetaData()))
        stopConnectTimer()
        delegate?.rtmpStreamConnected(self)
        processorPipelineQueue.async {
            self.processor.startEncoding(self)
        }
    }

    private func sendCreateStream() {
        connection.call(.createStream, arguments: []) { arguments in
            guard !arguments.isEmpty,
                  case let .number(id) = arguments[0],
                  id >= 0,
                  id <= Double(UInt32.max)
            else {
                return
            }
            self.streamId = UInt32(id)
            self.setState(state: .open)
        }
    }

    private func sendReleaseStream() {
        connection.call(.releaseStream, arguments: [.string(streamKey)])
    }

    private func sendFCPublish() {
        connection.call(.fcPublish, arguments: [.string(streamKey)])
    }

    private func sendFCUnpublish() {
        connection.call(.fcUnpublish, arguments: [.string(streamKey)])
    }

    private func sendDeleteStream() {
        _ = connection.socket.write(chunk: RtmpChunk(message: RtmpCommandMessage(
            streamId: streamId,
            transactionId: 0,
            commandType: .amf0Command,
            commandName: .deleteStream,
            commandObject: nil,
            arguments: [.number(Double(streamId))]
        )))
    }

    private func sendCloseStream() {
        _ = connection.socket.write(chunk: RtmpChunk(
            type: .zero,
            chunkStreamId: RtmpChunk.ChunkStreamId.command.rawValue,
            message: RtmpCommandMessage(
                streamId: 0,
                transactionId: 0,
                commandType: .amf0Command,
                commandName: .closeStream,
                commandObject: nil,
                arguments: [.number(Double(streamId))]
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
        info.bitrateStats.mutate { $0.add(bytesTransferred: length) }
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
        info.bitrateStats.mutate { $0.add(bytesTransferred: length) }
    }

    private func audioEncoderOutputFormatInternal(_ format: AVAudioFormat) {
        guard let buffer = makeRtmpAudioSequenceHeader(format) else {
            return
        }
        handleEncodedAudioBuffer(buffer, 0)
    }

    private func audioEncoderOutputBufferInternal(_ audioBuffer: AVAudioCompressedBuffer,
                                                  _ presentationTimeStamp: CMTime)
    {
        guard let timestamp = timestamps.audio(presentationTimeStamp.seconds) else {
            logger.info("rtmp: \(name): Dropping audio buffer")
            return
        }
        handleEncodedAudioBuffer(makeRtmpAudioFrame(audioBuffer), timestamp)
    }

    private func videoEncoderOutputFormatInternal(
        _ format: VideoEncoderSettings.Format,
        _ formatDescription: CMFormatDescription
    ) {
        guard let buffer = makeRtmpVideoSequenceHeader(format, formatDescription) else {
            return
        }
        handleEncodedVideoBuffer(buffer, 0)
    }

    private func videoEncoderOutputSampleBufferInternal(_ format: VideoEncoderSettings.Format,
                                                        _ sampleBuffer: CMSampleBuffer)
    {
        let decodeTimeStamp = if sampleBuffer.decodeTimeStamp.isValid {
            sampleBuffer.decodeTimeStamp
        } else {
            sampleBuffer.presentationTimeStamp
        }
        guard let data = sampleBuffer.dataBuffer?.data,
              let timestamp = timestamps.video(decodeTimeStamp.seconds)
        else {
            logger.info("rtmp: \(name): Dropping video buffer")
            return
        }
        handleEncodedVideoBuffer(makeRtmpVideoFrame(format, sampleBuffer, data), timestamp)
    }
}

extension RtmpStream: AudioEncoderDelegate {
    func audioEncoderOutputFormat(_ format: AVAudioFormat) {
        queue.async {
            self.audioEncoderOutputFormatInternal(format)
        }
    }

    func audioEncoderOutputBuffer(_ buffer: AVAudioCompressedBuffer, _ presentationTimeStamp: CMTime) {
        queue.async {
            self.audioEncoderOutputBufferInternal(buffer, presentationTimeStamp)
        }
    }
}

extension RtmpStream: VideoEncoderDelegate {
    func videoEncoderOutputFormat(_ encoder: VideoEncoder, _ formatDescription: CMFormatDescription) {
        let format = encoder.settings.value.format
        queue.async {
            self.videoEncoderOutputFormatInternal(format, formatDescription)
        }
    }

    func videoEncoderOutputSampleBuffer(_ codec: VideoEncoder,
                                        _ sampleBuffer: CMSampleBuffer,
                                        _: CMTime)
    {
        let format = codec.settings.value.format
        queue.async {
            self.videoEncoderOutputSampleBufferInternal(format, sampleBuffer)
        }
    }
}
