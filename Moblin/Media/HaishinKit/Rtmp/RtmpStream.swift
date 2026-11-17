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

enum RtmpConnectionCode: String {
    case connectClosed = "NetConnection.Connect.Closed"
    case connectFailed = "NetConnection.Connect.Failed"
    case connectRejected = "NetConnection.Connect.Rejected"
    case connectSuccess = "NetConnection.Connect.Success"

    func eventData() -> AsObject {
        [
            "code": .string(rawValue),
        ]
    }
}

func makeSanJoseAuthCommand(_ url: URL, description: String) -> String {
    var command = url.absoluteString
    guard let index = description.firstIndex(of: "?") else {
        return command
    }
    let query = String(description[description.index(index, offsetBy: 1)...])
    let challenge = String(format: "%08x", UInt32.random(in: 0 ... UInt32.max))
    guard let dictionary = URL(string: "http://localhost?" + query)?.dictionaryFromQuery(),
          let salt = dictionary["salt"],
          let user = url.user,
          let password = url.password
    else {
        return command
    }
    var response = calculateMd5Base64("\(user)\(salt)\(password)")
    if let opaque = dictionary["opaque"] {
        command += "&opaque=\(opaque)"
        response += opaque
    } else if let challenge: String = dictionary["challenge"] {
        response += challenge
    }
    response = calculateMd5Base64("\(response)\(challenge)")
    command += "&challenge=\(challenge)&response=\(response)"
    return command
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
    let name: String
    private var streamId: UInt32 = 0
    private var state: State = .initialized
    private var startedAt = Date()
    private var audioChunkType: RtmpChunkType = .zero
    private var videoChunkType: RtmpChunkType = .zero
    private var dataTimeStamps: [String: Date] = [:]
    private var streamKey = ""
    private var url: String = ""
    private var uri: URL?
    private var socket: RtmpSocket
    private let chunkReader = RtmpChunkReader()
    var callCompletions: [Int: ([AsValue]) -> Void] = [:]
    private var nextTransactionId = 0
    private let connectTimer: SimpleTimer
    private let statsTimer: SimpleTimer
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
        statsTimer = SimpleTimer(queue: queue)
        socket = RtmpSocket(name: name, queue: queue)
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

    private func connectInternal() {
        startConnectTimer()
        connectSocket(url)
    }

    private func connectSocket(_ url: String) {
        guard let uri = URL(string: url), let scheme = uri.scheme, let host = uri.host else {
            return
        }
        self.uri = uri
        chunkReader.clear()
        socket = RtmpSocket(name: name, queue: queue)
        socket.delegate = self
        if scheme == "rtmps" {
            socket.connect(host: host, port: uri.port ?? 443, tlsOptions: .init())
        } else {
            socket.connect(host: host, port: uri.port ?? 1935, tlsOptions: nil)
        }
    }

    private func disconnectInternal() {
        statsTimer.stop()
        setState(state: .initialized)
        stopConnectTimer()
        processorPipelineQueue.async {
            self.processor.stopEncoding(self)
        }
        socket.close(isDisconnected: false)
        socket = RtmpSocket(name: name, queue: queue)
    }

    private func call(
        _ commandName: RtmpCommandName,
        arguments: [AsValue],
        onCompleted: (([AsValue]) -> Void)? = nil
    ) {
        let message = RtmpCommandMessage(
            streamId: 0,
            transactionId: getNextTransactionId(),
            commandType: .amf0Command,
            commandName: commandName,
            commandObject: nil,
            arguments: arguments
        )
        if let onCompleted {
            callCompletions[message.transactionId] = onCompleted
        }
        _ = socket.write(chunk: RtmpChunk(message: message))
    }

    private func getNextTransactionId() -> Int {
        nextTransactionId += 1
        return nextTransactionId
    }

    private func on(data: AsObject) {
        queue.async {
            self.handleStatus(data: data)
        }
    }

    private func handleStatus(data: AsObject) {
        guard case let .string(code) = data["code"] else {
            return
        }
        switch RtmpConnectionCode(rawValue: code) {
        case .connectSuccess:
            handleConnectSuccess()
        case .connectRejected:
            handleConnectRejected(data: data)
        case .connectClosed:
            disconnectInternal()
        default:
            break
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

    private func handleConnectSuccess() {
        socket.maximumChunkSizeToServer = 1024 * 8
        _ = socket.write(chunk: RtmpChunk(
            type: .zero,
            chunkStreamId: RtmpChunk.ChunkStreamId.control.rawValue,
            message: RtmpSetChunkSizeMessage(UInt32(socket.maximumChunkSizeToServer))
        ))
    }

    private func handleConnectRejected(data: AsObject) {
        guard
            let uri,
            let user = uri.user,
            let password = uri.password,
            case let .string(description) = data["description"]
        else {
            return
        }
        socket.close(isDisconnected: false)
        if description.contains("reason=nosuchuser") {
        } else if description.contains("reason=authfailed") {
        } else if description.contains("reason=needauth") {
            connectSocket(makeSanJoseAuthCommand(uri, description: description))
        } else if description.contains("authmod=adobe") {
            if user.isEmpty || password.isEmpty {
                disconnectInternal()
            } else {
                let query = uri.query ?? ""
                let command = uri.absoluteString + (query.isEmpty ? "?" : "&") + "authmod=adobe&user=\(user)"
                connectSocket(command)
            }
        }
    }

    private func makeConnectChunk() -> RtmpChunk? {
        guard let uri else {
            return nil
        }
        var app = String(uri.path.trimmingPrefix(while: { $0 == "/" }))
        if let query = uri.query {
            app += "?" + query
        }
        let message = RtmpCommandMessage(
            streamId: 0,
            transactionId: getNextTransactionId(),
            commandType: .amf0Command,
            commandName: .connect,
            commandObject: [
                "app": .string(app),
                "flashVer": .string("FMLE/3.0 (compatible; FMSc/1.0)"),
                "swfUrl": .null,
                "tcUrl": .string(uri.absoluteWithoutAuthenticationString),
                "fpad": .bool(false),
                "capabilities": .number(239),
                "audioCodecs": .number(0x0400),
                "videoCodecs": .number(0x0080),
                "videoFunction": .number(1),
                "pageUrl": .null,
                "objectEncoding": .number(0),
            ],
            arguments: []
        )
        return RtmpChunk(message: message)
    }

    private func handleHandshakeDone() {
        guard let chunk = makeConnectChunk() else {
            disconnectInternal()
            return
        }
        _ = socket.write(chunk: chunk)
        statsTimer.startPeriodic(interval: 1.0) { [weak self] in
            self?.info.onTimeout()
        }
    }

    private func handleClosed() {
        nextTransactionId = 0
        callCompletions.removeAll()
        chunkReader.clear()
    }

    private func processMessage(message: RtmpMessage) {
        if let message = message as? RtmpSetChunkSizeMessage {
            chunkReader.maximumChunkSize = Int(message.size)
        } else if let message = message as? RtmpAcknowledgementMessage {
            info.onAck(sequence: message.sequence)
        } else if let message = message as? RtmpUserControlMessage {
            processMessageUserControl(message: message)
        } else if message is RtmpWindowAcknowledgementSizeMessage {
            _ = socket.write(chunk: RtmpChunk(
                type: .zero,
                chunkStreamId: RtmpChunk.ChunkStreamId.control.rawValue,
                message: RtmpWindowAcknowledgementSizeMessage(100_000)
            ))
        } else if let message = message as? RtmpCommandMessage {
            processMessageCommand(message: message)
        } else if let message = message as? RtmpDataMessage {
            info.bitrateStats.mutate { $0.add(bytesTransferred: message.encoded.count) }
        }
    }

    private func processMessageUserControl(message: RtmpUserControlMessage) {
        switch message.event {
        case .ping:
            _ = socket.write(chunk: RtmpChunk(
                type: .zero,
                chunkStreamId: RtmpChunk.ChunkStreamId.control.rawValue,
                message: RtmpUserControlMessage(event: .pong, value: message.value)
            ))
        default:
            break
        }
    }

    private func processMessageCommand(message: RtmpCommandMessage) {
        guard let completion = callCompletions.removeValue(forKey: message.transactionId) else {
            switch message.commandName {
            case .close:
                disconnectInternal()
            default:
                if case let .object(data) = message.arguments.first {
                    on(data: data)
                }
            }
            return
        }
        switch message.commandName {
        case .result:
            completion(message.arguments)
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

    private func startConnectTimer() {
        connectTimer.startSingleShot(timeout: 20) { [weak self] in
            guard let self else {
                return
            }
            logger.info("rtmp: \(name): Connect timeout")
            socket.close(isDisconnected: true)
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
        let length = socket.write(chunk: chunk)
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
        _ = socket.write(chunk: RtmpChunk(message: RtmpCommandMessage(
            streamId: streamId,
            transactionId: getNextTransactionId(),
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
        call(.createStream, arguments: []) { arguments in
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
        call(.releaseStream, arguments: [.string(streamKey)])
    }

    private func sendFCPublish() {
        call(.fcPublish, arguments: [.string(streamKey)])
    }

    private func sendFCUnpublish() {
        call(.fcUnpublish, arguments: [.string(streamKey)])
    }

    private func sendDeleteStream() {
        _ = socket.write(chunk: RtmpChunk(message: RtmpCommandMessage(
            streamId: streamId,
            transactionId: 0,
            commandType: .amf0Command,
            commandName: .deleteStream,
            commandObject: nil,
            arguments: [.number(Double(streamId))]
        )))
    }

    private func sendCloseStream() {
        _ = socket.write(chunk: RtmpChunk(
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
        let length = socket.write(chunk: RtmpChunk(
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
        let length = socket.write(chunk: RtmpChunk(
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

extension RtmpStream: RtmpSocketDelegate {
    func socketReadyStateChanged(readyState: RtmpSocketReadyState) {
        switch readyState {
        case .handshakeDone:
            handleHandshakeDone()
        case .closed:
            handleClosed()
        default:
            break
        }
    }

    func socketUpdateStats(totalBytesSent: Int64) {
        info.onWritten(sequence: totalBytesSent)
    }

    func socketDataReceived(data: Data) -> Data {
        chunkReader.read(data: data) { message in
            processMessage(message: message)
        }
    }

    func socketPost(data: AsObject) {
        on(data: data)
    }
}
