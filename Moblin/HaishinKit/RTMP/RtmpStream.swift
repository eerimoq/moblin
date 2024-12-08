import AVFoundation

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

enum RtmpStreamCode: String {
    case publishStart = "NetStream.Publish.Start"
    case videoDimensionChange = "NetStream.Video.DimensionChange"

    func eventData() -> ASObject {
        return [
            "code": rawValue,
        ]
    }
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
        didChangeReadyState(state, oldValue: oldState)
    }

    static let aac = FLVAudioCodec.aac.rawValue << 4 | FLVSoundRate.kHz44.rawValue << 2 | FLVSoundSize
        .snd16bit.rawValue << 1 | FLVSoundType.stereo.rawValue

    // Inbound
    var audioTimestampZero = -1.0
    var videoTimestampZero = -1.0
    var audioTimeStamp = 0.0
    var videoTimeStamp = 0.0

    private var messages: [RtmpCommandMessage] = []
    private var startedAt = Date()
    private var dispatcher: (any EventDispatcherConvertible)!
    private var audioChunkType: RTMPChunkType = .zero
    private var videoChunkType: RTMPChunkType = .zero
    private var dataTimeStamps: [String: Date] = [:]
    private weak var rtmpConnection: RtmpConnection?

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
        dispatcher = EventDispatcher(target: self)
        connection.streams.append(self)
        addEventListener(.rtmpStatus, selector: #selector(on(status:)), observer: self)
        connection.addEventListener(.rtmpStatus, selector: #selector(on(status:)), observer: self)
        if connection.connected {
            connection.createStream(self)
        }
    }

    deinit {
        mixer.stopRunning()
        removeEventListener(.rtmpStatus, selector: #selector(on(status:)), observer: self)
        rtmpConnection?.removeEventListener(.rtmpStatus, selector: #selector(on(status:)), observer: self)
    }

    func publish(_ name: String?) {
        netStreamLockQueue.async {
            self.publishInner(name)
        }
    }

    func close() {
        netStreamLockQueue.async {
            self.closeInternal()
        }
    }

    private func publishInner(_ name: String?) {
        guard let name else {
            switch readyState {
            case .publish, .publishing:
                closeInternal()
            default:
                break
            }
            return
        }
        if info.resourceName == name && readyState == .publishing {
            return
        }
        info.resourceName = name
        let message = RtmpCommandMessage(
            streamId: id,
            transactionId: 0,
            objectEncoding: .amf0,
            commandName: "publish",
            commandObject: nil,
            arguments: [name, "live"]
        )
        switch readyState {
        case .initialized:
            messages.append(message)
        default:
            setReadyState(state: .publish)
            _ = rtmpConnection?.socket.write(chunk: RtmpChunk(message: message))
        }
    }

    func onTimeout() {
        info.onTimeout()
    }

    private func send(handlerName: String, arguments: Any?...) {
        netStreamLockQueue.async {
            self.sendInner(handlerName: handlerName, arguments: arguments)
        }
    }

    private func sendInner(handlerName: String, arguments: Any?...) {
        guard let rtmpConnection = rtmpConnection, readyState == .publishing else {
            return
        }
        let dataWasSent = dataTimeStamps[handlerName] != nil
        let timestmap = dataWasSent ?
            UInt32((dataTimeStamps[handlerName]?.timeIntervalSinceNow ?? 0) * -1000) :
            UInt32(startedAt.timeIntervalSinceNow * -1000)
        let chunk = RtmpChunk(
            type: dataWasSent ? RTMPChunkType.one : RTMPChunkType.zero,
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

    private func createMetaData() -> ASObject {
        var metadata: [String: Any] = [:]
        if mixer.video.device != nil {
            let settings = mixer.video.encoder.settings.value
            metadata["width"] = settings.videoSize.width
            metadata["height"] = settings.videoSize.height
            metadata["framerate"] = mixer.video.frameRate
            switch settings.format {
            case .h264:
                metadata["videocodecid"] = FLVVideoCodec.avc.rawValue
            case .hevc:
                metadata["videocodecid"] = FLVVideoFourCC.hevc.rawValue
            }
            metadata["videodatarate"] = settings.bitRate / 1000
        }
        if mixer.audio.device != nil {
            metadata["audiocodecid"] = FLVAudioCodec.aac.rawValue
            metadata["audiodatarate"] = mixer.audio.encoder.settings.bitRate / 1000
            if let sampleRate = mixer.audio.encoder.inSourceFormat?.mSampleRate {
                metadata["audiosamplerate"] = sampleRate
            }
        }
        return metadata
    }

    func closeInternal() {
        setReadyState(state: .initialized)
    }

    private func didChangeReadyState(_ readyState: ReadyState, oldValue: ReadyState) {
        guard let rtmpConnection else {
            return
        }
        if oldValue == .publishing {
            FCUnpublish()
            deleteStream()
            closeStream()
            mixer.stopEncoding()
        }
        switch readyState {
        case .open:
            info.clear()
            delegate?.streamDidOpen(self)
            for message in messages {
                rtmpConnection.currentTransactionId += 1
                message.streamId = id
                message.transactionId = rtmpConnection.currentTransactionId
                switch message.commandName {
                case "publish":
                    setReadyState(state: .publish)
                default:
                    break
                }
                _ = rtmpConnection.socket.write(chunk: RtmpChunk(message: message))
            }
            messages.removeAll()
        case .publish:
            startedAt = .init()
            baseTimeStamp = -1.0
            prevRebasedAudioTimeStamp = -1.0
            prevRebasedVideoTimeStamp = -1.0
            mixer.startRunning()
            videoChunkType = .zero
            audioChunkType = .zero
            dataTimeStamps.removeAll()
            FCPublish()
        case .publishing:
            send(handlerName: "@setDataFrame", arguments: "onMetaData", createMetaData())
            mixer.startEncoding(self)
        default:
            break
        }
    }

    @objc
    private func on(status: Notification) {
        guard let rtmpConnection,
              let event = Event.from(status),
              let data = event.data as? ASObject,
              let code = data["code"] as? String
        else {
            return
        }
        switch code {
        case RtmpConnectionCode.connectSuccess.rawValue:
            setReadyState(state: .initialized)
            rtmpConnection.createStream(self)
        case RtmpStreamCode.publishStart.rawValue:
            setReadyState(state: .publishing)
        default:
            break
        }
    }

    private func FCPublish() {
        guard let rtmpConnection, let name = info.resourceName,
              rtmpConnection.flashVer.contains("FMLE/")
        else {
            return
        }
        rtmpConnection.call("FCPublish", arguments: [name])
    }

    private func FCUnpublish() {
        guard let rtmpConnection, let name = info.resourceName, rtmpConnection.flashVer.contains("FMLE/") else {
            return
        }
        rtmpConnection.call("FCUnpublish", arguments: [name])
    }

    private func deleteStream() {
        guard let rtmpConnection else {
            return
        }
        _ = rtmpConnection.socket.write(chunk: RtmpChunk(message: RtmpCommandMessage(
            streamId: id,
            transactionId: 0,
            objectEncoding: .amf0,
            commandName: "deleteStream",
            commandObject: nil,
            arguments: [id]
        )))
    }

    private func closeStream() {
        guard let rtmpConnection else {
            return
        }
        _ = rtmpConnection.socket.write(chunk: RtmpChunk(
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
            chunkStreamId: FLVTagType.audio.streamId,
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
            chunkStreamId: FLVTagType.video.streamId,
            message: RtmpVideoMessage(streamId: id, timestamp: timestamp, payload: buffer)
        ))
        videoChunkType = .one
        info.byteCount.mutate { $0 += Int64(length) }
    }

    private func audioCodecOutputFormatInner(_ format: AVAudioFormat) {
        var buffer = Data([RtmpStream.aac, FLVAACPacketType.seq.rawValue])
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
        var buffer = Data([RtmpStream.aac, FLVAACPacketType.raw.rawValue])
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
        let frameType = sampleBuffer.isSync ? FLVFrameType.key : FLVFrameType.inter
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

extension RtmpStream: EventDispatcherConvertible {
    func addEventListener(_ type: Event.Name, selector: Selector, observer: AnyObject? = nil) {
        dispatcher.addEventListener(type, selector: selector, observer: observer)
    }

    func removeEventListener(_ type: Event.Name, selector: Selector, observer: AnyObject? = nil) {
        dispatcher.removeEventListener(type, selector: selector, observer: observer)
    }

    func dispatch(_ type: Event.Name, data: Any?) {
        dispatcher.dispatch(type, data: data)
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
