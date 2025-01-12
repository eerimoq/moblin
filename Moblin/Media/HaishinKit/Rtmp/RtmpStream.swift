import AVFoundation

private let extendedVideoHeader: UInt8 = 0b1000_0000

private func makeVideoHeader(_ frameType: FlvFrameType,
                             _ fourCc: FlvVideoFourCC,
                             _ trackId: UInt8,
                             _ avcPacketType: FlvAvcPacketType, // Not part of FLV?
                             _ videoPacketType: FlvVideoPacketType) -> Data
{
    let writer = ByteArray()
    if trackId == 0 {
        if fourCc == .avc1 {
            writer.writeUInt8((frameType.rawValue << 4) | FlvVideoCodec.avc.rawValue)
            writer.writeUInt8(avcPacketType.rawValue)
        } else {
            writer.writeUInt8(extendedVideoHeader | (frameType.rawValue << 4) | videoPacketType.rawValue)
            writer.writeUInt32(fourCc.rawValue)
        }
    } else {
        writer.writeUInt8(extendedVideoHeader | (frameType.rawValue << 4) | FlvVideoPacketType.multiTrack.rawValue)
        writer.writeUInt8((FlvAvMultitrackType.oneTrack.rawValue << 4) | FlvVideoPacketType.codedFramesX.rawValue)
        writer.writeUInt32(fourCc.rawValue)
        writer.writeUInt8(trackId)
    }
    return writer.data
}

private func makeAvcVideoTagHeader(_ frameType: FlvFrameType, _ packetType: FlvAvcPacketType) -> Data {
    return makeVideoHeader(frameType, .avc1, 0, packetType, .sequenceStart)
}

private func makeHevcExtendedTagHeader(_ frameType: FlvFrameType, _ packetType: FlvVideoPacketType) -> Data {
    return makeVideoHeader(frameType, .hevc, 0, .nal, packetType)
}

enum RtmpStreamCode: String {
    case publishStart = "NetStream.Publish.Start"
    case videoDimensionChange = "NetStream.Video.DimensionChange"
}

class RtmpStream: NetStream {
    enum ReadyState: UInt8 {
        case initialized
        case open
        case publish
        case publishing
    }

    static let defaultID: UInt32 = 0
    var info = RtmpStreamInfo()

    var id = RtmpStream.defaultID
    private var readyState: ReadyState = .initialized

    func setReadyState(state: ReadyState) {
        guard state != readyState else {
            return
        }
        let oldState = readyState
        readyState = state
        logger.info("rtmp: Settings stream state \(oldState) -> \(state)")
        didChangeReadyState(state, oldReadyState: oldState)
    }

    static let aac = FlvAudioCodec.aac.rawValue << 4 | FlvSoundRate.kHz44.rawValue << 2 | FlvSoundSize
        .snd16bit.rawValue << 1 | FlvSoundType.stereo.rawValue

    private var messages: [RtmpCommandMessage] = []
    private var startedAt = Date()
    private var dispatcher: (any RtmpEventDispatcherConvertible)!
    private var audioChunkType: RtmpChunkType = .zero
    private var videoChunkType: RtmpChunkType = .zero
    private var dataTimeStamps: [String: Date] = [:]
    private weak var rtmpConnection: RtmpConnection?
    private var streamKey = ""

    // Outbound
    private var baseTimeStamp = -1.0
    private var audioTimeStampDelta = 0.0
    private var videoTimeStampDelta = 0.0
    private var prevRebasedAudioTimeStamp = -1.0
    private var prevRebasedVideoTimeStamp = -1.0
    private let compositionTimeOffset = CMTime(value: 3, timescale: 30).seconds

    init(connection: RtmpConnection) {
        rtmpConnection = connection
        super.init()
        dispatcher = RtmpEventDispatcher(target: self)
        connection.streams.append(self)
        addEventListener(.rtmpStatus, selector: #selector(on(status:)), observer: self)
        connection.addEventListener(.rtmpStatus, selector: #selector(on(status:)), observer: self)
        if connection.connected {
            sendFCPublish()
            connection.createStream(self)
        }
    }

    deinit {
        mixer.stopRunning()
        removeEventListener(.rtmpStatus, selector: #selector(on(status:)), observer: self)
        rtmpConnection?.removeEventListener(.rtmpStatus, selector: #selector(on(status:)), observer: self)
    }

    func setStreamKey(_ streamKey: String) {
        self.streamKey = streamKey
    }

    func publish() {
        netStreamLockQueue.async {
            self.publishInner()
        }
    }

    func close() {
        netStreamLockQueue.async {
            self.closeInternal()
        }
    }

    private func publishInner() {
        guard let rtmpConnection else {
            return
        }
        info.resourceName = streamKey
        let message = RtmpCommandMessage(
            streamId: id,
            transactionId: rtmpConnection.getNextTransactionId(),
            objectEncoding: .amf0,
            commandName: "publish",
            commandObject: nil,
            arguments: [streamKey, "live"]
        )
        switch readyState {
        case .initialized:
            messages.append(message)
        default:
            setReadyState(state: .publish)
            _ = rtmpConnection.socket.write(chunk: RtmpChunk(message: message))
        }
    }

    func onTimeout() {
        info.onTimeout()
    }

    private func send(handlerName: String, arguments: Any?...) {
        guard let rtmpConnection = rtmpConnection, readyState == .publishing else {
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
                streamId: id,
                objectEncoding: .amf0,
                timestamp: timestmap,
                handlerName: handlerName,
                arguments: arguments
            )
        )
        let length = rtmpConnection.socket.write(chunk: chunk)
        dataTimeStamps[handlerName] = .init()
        info.byteCount.mutate { $0 += Int64(length) }
    }

    private func createOnMetaData() -> AsObject {
        let audioEncoders = mixer.audio.getEncoders()
        let videoEncoders = mixer.video.getEncoders()
        if audioEncoders.count == 1, videoEncoders.count == 1 {
            return createOnMetaDataLegacy(audioEncoders.first!, videoEncoders.first!)
        } else {
            return createOnMetaDataMultiTrack(audioEncoders, videoEncoders)
        }
    }

    private func createOnMetaDataLegacy(_ audioEncoder: AudioCodec, _ videoEncoder: VideoCodec) -> AsObject {
        var metadata: [String: Any] = [:]
        let settings = videoEncoder.settings.value
        metadata["width"] = settings.videoSize.width
        metadata["height"] = settings.videoSize.height
        metadata["framerate"] = mixer.video.frameRate
        switch settings.format {
        case .h264:
            metadata["videocodecid"] = FlvVideoCodec.avc.rawValue
        case .hevc:
            metadata["videocodecid"] = FlvVideoFourCC.hevc.rawValue
        }
        metadata["videodatarate"] = settings.bitRate / 1000
        metadata["audiocodecid"] = FlvAudioCodec.aac.rawValue
        metadata["audiodatarate"] = audioEncoder.settings.bitRate / 1000
        if let sampleRate = audioEncoder.inSourceFormat?.mSampleRate {
            metadata["audiosamplerate"] = sampleRate
        }
        return metadata
    }

    private func createOnMetaDataMultiTrack(_ audioEncoders: [AudioCodec], _ videoEncoders: [VideoCodec]) -> AsObject {
        let metadata = createOnMetaDataLegacy(audioEncoders.first!, videoEncoders.first!)
        // var audioTrackIdInfoMap: [String: Any] = [:]
        // for (trackId, encoder) in audioEncoders.enumerated() {
        //     let settings = encoder.settings
        //     audioTrackIdInfoMap[String(trackId)] = [
        //         "audiodatarate": settings.bitRate / 1000,
        //         "channels": 1,
        //         "samplerate": 48000,
        //     ]
        // }
        // metadata["audioTrackIdInfoMap"] = audioTrackIdInfoMap
        // var videoTrackIdInfoMap: [String: Any] = [:]
        // for (trackId, encoder) in videoEncoders.enumerated() {
        //     let settings = encoder.settings.value
        //     videoTrackIdInfoMap[String(trackId)] = [
        //         "width": settings.videoSize.width,
        //         "height": settings.videoSize.height,
        //         "videodatarate": settings.bitRate / 1000,
        //     ]
        // }
        // metadata["videoTrackIdInfoMap"] = videoTrackIdInfoMap
        return metadata
    }

    func closeInternal() {
        setReadyState(state: .initialized)
    }

    private func didChangeReadyState(_ readyState: ReadyState, oldReadyState: ReadyState) {
        if oldReadyState == .publishing {
            sendFCUnpublish()
            sendDeleteStream()
            closeStream()
            mixer.stopEncoding()
        }
        switch readyState {
        case .open:
            handleOpen()
        case .publish:
            handlePublish()
        case .publishing:
            handlePublishing()
        default:
            break
        }
    }

    private func handleOpen() {
        guard let rtmpConnection else {
            return
        }
        info.clear()
        for message in messages {
            message.streamId = id
            message.transactionId = rtmpConnection.getNextTransactionId()
            switch message.commandName {
            case "publish":
                setReadyState(state: .publish)
            default:
                break
            }
            _ = rtmpConnection.socket.write(chunk: RtmpChunk(message: message))
        }
        messages.removeAll()
    }

    private func handlePublish() {
        startedAt = .init()
        baseTimeStamp = -1.0
        prevRebasedAudioTimeStamp = -1.0
        prevRebasedVideoTimeStamp = -1.0
        mixer.startRunning()
        videoChunkType = .zero
        audioChunkType = .zero
        dataTimeStamps.removeAll()
    }

    private func handlePublishing() {
        send(handlerName: "@setDataFrame", arguments: "onMetaData", createOnMetaData())
        mixer.startEncoding(self)
    }

    @objc
    private func on(status: Notification) {
        guard let event = RtmpEvent.from(status) else {
            return
        }
        netStreamLockQueue.async {
            self.onInternal(event: event)
        }
    }

    private func onInternal(event: RtmpEvent) {
        guard let rtmpConnection,
              let data = event.data as? AsObject,
              let code = data["code"] as? String
        else {
            return
        }
        logger.info("rtmp: Got event: \(code)")
        switch code {
        case RtmpConnectionCode.connectSuccess.rawValue:
            setReadyState(state: .initialized)
            sendFCPublish()
            rtmpConnection.createStream(self)
        case RtmpStreamCode.publishStart.rawValue:
            if readyState != .initialized {
                setReadyState(state: .publishing)
            }
        default:
            break
        }
    }

    private func sendFCPublish() {
        rtmpConnection?.call("FCPublish", arguments: [streamKey])
    }

    private func sendFCUnpublish() {
        rtmpConnection?.call("FCUnpublish", arguments: [info.resourceName])
    }

    private func sendDeleteStream() {
        _ = rtmpConnection?.socket.write(chunk: RtmpChunk(message: RtmpCommandMessage(
            streamId: id,
            transactionId: 0,
            objectEncoding: .amf0,
            commandName: "deleteStream",
            commandObject: nil,
            arguments: [id]
        )))
    }

    private func closeStream() {
        _ = rtmpConnection?.socket.write(chunk: RtmpChunk(
            type: .zero,
            chunkStreamId: RtmpChunk.ChunkStreamId.command.rawValue,
            message: RtmpCommandMessage(
                streamId: 0,
                transactionId: 0,
                objectEncoding: .amf0,
                commandName: "closeStream",
                commandObject: nil,
                arguments: [id]
            )
        ))
    }

    private func handleEncodedAudioBuffer(_ buffer: Data, _ timestamp: UInt32) {
        guard let rtmpConnection, readyState == .publishing else {
            return
        }
        let length = rtmpConnection.socket.write(chunk: RtmpChunk(
            type: audioChunkType,
            chunkStreamId: FlvTagType.audio.streamId,
            message: RtmpAudioMessage(streamId: id, timestamp: timestamp, payload: buffer)
        ))
        audioChunkType = .one
        info.byteCount.mutate { $0 += Int64(length) }
    }

    private func handleEncodedVideoBuffer(_ buffer: Data, _ timestamp: UInt32) {
        guard let rtmpConnection, readyState == .publishing else {
            return
        }
        let length = rtmpConnection.socket.write(chunk: RtmpChunk(
            type: videoChunkType,
            chunkStreamId: FlvTagType.video.streamId,
            message: RtmpVideoMessage(streamId: id, timestamp: timestamp, payload: buffer)
        ))
        videoChunkType = .one
        info.byteCount.mutate { $0 += Int64(length) }
    }

    private func audioCodecOutputFormatInner(_ format: AVAudioFormat) {
        var buffer = Data([RtmpStream.aac, FlvAacPacketType.seq.rawValue])
        buffer.append(contentsOf: MpegTsAudioConfig(formatDescription: format.formatDescription).bytes)
        handleEncodedAudioBuffer(buffer, 0)
    }

    private func audioCodecOutputBufferInner(_ buffer: AVAudioBuffer, _ presentationTimeStamp: CMTime) {
        guard let rebasedTimestamp = rebaseTimeStamp(timestamp: presentationTimeStamp.seconds) else {
            return
        }
        var delta = 0.0
        if prevRebasedAudioTimeStamp != -1.0 {
            delta = (rebasedTimestamp - prevRebasedAudioTimeStamp) * 1000
        }
        guard let audioBuffer = buffer as? AVAudioCompressedBuffer, delta >= 0 else {
            return
        }
        var buffer = Data([RtmpStream.aac, FlvAacPacketType.raw.rawValue])
        buffer.append(
            audioBuffer.data.assumingMemoryBound(to: UInt8.self),
            count: Int(audioBuffer.byteLength)
        )
        prevRebasedAudioTimeStamp = rebasedTimestamp
        handleEncodedAudioBuffer(buffer, UInt32(audioTimeStampDelta))
        audioTimeStampDelta -= floor(audioTimeStampDelta)
        audioTimeStampDelta += delta
    }

    private func videoCodecOutputFormatInner(
        _ format: VideoCodecSettings.Format,
        _ formatDescription: CMFormatDescription
    ) {
        var buffer: Data
        switch format {
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
        handleEncodedVideoBuffer(buffer, 0)
    }

    private func videoCodecOutputSampleBufferInner(_ format: VideoCodecSettings.Format,
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
        let compositionTime = calcVideoCompositionTime(sampleBuffer)
        var delta = 0.0
        if prevRebasedVideoTimeStamp != -1.0 {
            delta = (rebasedTimestamp - prevRebasedVideoTimeStamp) * 1000
        }
        guard let data = sampleBuffer.dataBuffer?.data, delta >= 0 else {
            return
        }
        var buffer: Data
        let frameType = sampleBuffer.isSync ? FlvFrameType.key : FlvFrameType.inter
        switch format {
        case .h264:
            buffer = makeAvcVideoTagHeader(frameType, .nal)
        case .hevc:
            buffer = makeHevcExtendedTagHeader(frameType, .codedFrames)
        }
        buffer.append(contentsOf: compositionTime.bigEndian.data[1 ..< 4])
        buffer.append(data)
        prevRebasedVideoTimeStamp = rebasedTimestamp
        handleEncodedVideoBuffer(buffer, UInt32(videoTimeStampDelta))
        videoTimeStampDelta -= floor(videoTimeStampDelta)
        videoTimeStampDelta += delta
    }

    private func calcVideoCompositionTime(_ sampleBuffer: CMSampleBuffer) -> Int32 {
        let presentationTimeStamp = sampleBuffer.presentationTimeStamp
        let decodeTimeStamp = sampleBuffer.decodeTimeStamp
        guard decodeTimeStamp.isValid, decodeTimeStamp != presentationTimeStamp else {
            return 0
        }
        guard let rebasedTimestamp = rebaseTimeStamp(timestamp: presentationTimeStamp.seconds) else {
            return 0
        }
        return Int32((rebasedTimestamp - prevRebasedVideoTimeStamp + compositionTimeOffset) * 1000)
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

extension RtmpStream: RtmpEventDispatcherConvertible {
    func addEventListener(_ type: RtmpEvent.Name, selector: Selector, observer: AnyObject? = nil) {
        dispatcher.addEventListener(type, selector: selector, observer: observer)
    }

    func removeEventListener(_ type: RtmpEvent.Name, selector: Selector, observer: AnyObject? = nil) {
        dispatcher.removeEventListener(type, selector: selector, observer: observer)
    }
}

extension RtmpStream: AudioCodecDelegate {
    func audioCodecOutputFormat(_ format: AVAudioFormat) {
        netStreamLockQueue.async {
            self.audioCodecOutputFormatInner(format)
        }
    }

    func audioCodecOutputBuffer(_ buffer: AVAudioBuffer, _ presentationTimeStamp: CMTime) {
        netStreamLockQueue.async {
            self.audioCodecOutputBufferInner(buffer, presentationTimeStamp)
        }
    }
}

extension RtmpStream: VideoCodecDelegate {
    func videoCodecOutputFormat(_ codec: VideoCodec, _ formatDescription: CMFormatDescription) {
        let format = codec.settings.value.format
        netStreamLockQueue.async {
            self.videoCodecOutputFormatInner(format, formatDescription)
        }
    }

    func videoCodecOutputSampleBuffer(_ codec: VideoCodec, _ sampleBuffer: CMSampleBuffer) {
        let format = codec.settings.value.format
        netStreamLockQueue.async {
            self.videoCodecOutputSampleBufferInner(format, sampleBuffer)
        }
    }
}
