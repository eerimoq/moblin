import AVFoundation
import Foundation
import Network

class RtmpServerChunkStream {
    private var messageBody: Data
    var messageLength: Int
    var messageTypeId: UInt8
    var messageTimestamp: UInt32
    var messageStreamId: UInt32
    var isMessageType0: Bool
    var extendedTimestampPresentInType3: Bool
    private weak var client: RtmpServerClient?
    private var streamId: UInt16
    private var mediaTimestamp: Double = 0
    private var mediaTimestampZero: Double
    private var audioTimestamp: Double
    private var videoTimestamp: Double
    private var formatDescription: CMVideoFormatDescription?
    private var videoDecoder: VideoCodec?
    private var videoCodecLockQueue = DispatchQueue(label: "com.eerimoq.Moblin.VideoCodec")
    private var audioBuffer: AVAudioCompressedBuffer?
    private var audioDecoder: AVAudioConverter?
    private var pcmAudioFormat: AVAudioFormat?
    private var firstAudioBufferTimestamp: ContinuousClock.Instant?
    private var totalNumberOfAudioSamples: UInt64 = 0
    private var firstVideoFrameTimestamp: ContinuousClock.Instant?
    private var totalNumberOfVideoFrames: UInt64 = 0

    init(client: RtmpServerClient, streamId: UInt16) {
        self.client = client
        self.streamId = streamId
        messageBody = Data()
        messageLength = 0
        messageTypeId = 0
        messageTimestamp = 0
        messageStreamId = 0
        mediaTimestampZero = -1
        audioTimestamp = 0
        videoTimestamp = 0
        isMessageType0 = true
        extendedTimestampPresentInType3 = false
    }

    func stop() {
        videoDecoder?.stopRunning()
        videoDecoder = nil
        client = nil
    }

    func getChunkDataSize() -> Int {
        guard let client else {
            return 0
        }
        return min(client.chunkSizeFromClient, messageRemain())
    }

    func handleBody(data: Data) {
        messageBody += data
        // logger.info("rtmp-server: client: Got \(data.count) chunk data and \(messageRemain()) remain")
        if messageRemain() == 0 {
            processMessage()
            messageBody.removeAll(keepingCapacity: true)
        }
    }

    func getInfo() -> RtmpServerClientInfo {
        var audioSamplesPerSecond = 0.0
        var videoFps = 0.0
        let now = ContinuousClock.now
        if let firstTimestamp = firstAudioBufferTimestamp {
            audioSamplesPerSecond = Double(totalNumberOfAudioSamples) / firstTimestamp.duration(to: now)
                .seconds
            firstAudioBufferTimestamp = now
            totalNumberOfAudioSamples = 0
        }
        if let firstTimestamp = firstVideoFrameTimestamp {
            videoFps = Double(totalNumberOfVideoFrames) / firstTimestamp.duration(to: now).seconds
            firstVideoFrameTimestamp = now
            totalNumberOfVideoFrames = 0
        }
        return RtmpServerClientInfo(audioSamplesPerSecond: audioSamplesPerSecond, videoFps: videoFps)
    }

    private func messageRemain() -> Int {
        return messageLength - messageBody.count
    }

    private func processMessage() {
        guard let messageType = RtmpMessageType(rawValue: messageTypeId) else {
            logger.info("rtmp-server: client: Bad message type \(messageTypeId)")
            return
        }
        if isMessageType0 {
            mediaTimestamp = Double(messageTimestamp)
        } else {
            mediaTimestamp += Double(messageTimestamp)
        }
        // logger.info("rtmp-server: client: Processing message \(messageType)")
        switch messageType {
        case .amf0Command:
            processMessageAmf0Command()
        case .amf0Data:
            processMessageAmf0Data()
        case .chunkSize:
            processMessageChunkSize()
        case .windowAck:
            processMessageWindowAck()
        case .video:
            processMessageVideo()
        case .audio:
            processMessageAudio()
        default:
            logger.info("rtmp-server: client: Message type \(messageType) not supported")
        }
    }

    private func processMessageAmf0Command() {
        guard let client else {
            return
        }
        let amf0 = AMF0Serializer(data: messageBody)
        let commandName: String
        let transactionId: Int
        let commandObject: ASObject
        var arguments: [Any?]
        do {
            commandName = try amf0.deserialize()
            transactionId = try amf0.deserialize()
            commandObject = try amf0.deserialize()
            arguments = []
            if amf0.bytesAvailable > 0 {
                try arguments.append(amf0.deserialize())
            }
            /* logger.info("""
             rtmp-server: client: Command: \(commandName), Object: \(commandObject), \
             Arguments: \(arguments)
             """) */
        } catch {
            client.stopInternal(reason: "AMF-0 decode error \(error)")
            return
        }
        switch commandName {
        case "connect":
            processMessageAmf0CommandConnect(transactionId: transactionId, commandObject: commandObject)
        case "FCPublish":
            processMessageAmf0CommandFCPublish(transactionId: transactionId)
        case "FCUnpublish":
            processMessageAmf0CommandFCUnpublish(transactionId: transactionId)
        case "createStream":
            processMessageAmf0CommandCreateStream(transactionId: transactionId)
        case "deleteStream":
            processMessageAmf0CommandDeleteStream(transactionId: transactionId)
        case "publish":
            processMessageAmf0CommandPublish(transactionId: transactionId, arguments: arguments)
        default:
            logger.info("rtmp-server: client: Unsupported command \(commandName)")
        }
    }

    private func processMessageAmf0Data() {
        logger.info("rtmp-server: client: Ignoring AMF-0 data")
    }

    private func processMessageAmf0CommandConnect(transactionId: Int, commandObject: ASObject) {
        guard let client else {
            return
        }
        guard let url = commandObject["tcUrl"] as? String else {
            client.stopInternal(reason: "Stream URL missing")
            return
        }
        guard let url = URL(string: url) else {
            client.stopInternal(reason: "Invalid stream URL")
            return
        }
        guard url.path() == rtmpServerApp else {
            client.stopInternal(reason: "Not a camera path")
            return
        }
        client.sendMessage(chunk: RtmpChunk(
            type: .zero,
            chunkStreamId: RtmpChunk.ChunkStreamId.control.rawValue,
            message: RtmpWindowAcknowledgementSizeMessage(2_500_000)
        ))
        client.sendMessage(chunk: RtmpChunk(
            type: .zero,
            chunkStreamId: RtmpChunk.ChunkStreamId.control.rawValue,
            message: RtmpSetPeerBandwidthMessage(size: 2_500_000, limit: .dynamic)
        ))
        client.sendMessage(chunk: RtmpChunk(
            type: .zero,
            chunkStreamId: RtmpChunk.ChunkStreamId.control.rawValue,
            message: RtmpSetChunkSizeMessage(1024)
        ))
        client.sendMessage(chunk: RtmpChunk(
            type: .zero,
            chunkStreamId: streamId,
            message: RtmpCommandMessage(
                streamId: messageStreamId,
                transactionId: transactionId,
                objectEncoding: .amf0,
                commandName: "_result",
                commandObject: nil,
                arguments: [[
                    "level": "status",
                    "code": "NetConnection.Connect.Success",
                    "description": "Connection succeeded.",
                ]]
            )
        ))
    }

    private func processMessageAmf0CommandFCPublish(transactionId _: Int) {}

    private func processMessageAmf0CommandFCUnpublish(transactionId _: Int) {}

    private func processMessageAmf0CommandCreateStream(transactionId: Int) {
        guard let client else {
            return
        }
        client.sendMessage(chunk: RtmpChunk(
            type: .zero,
            chunkStreamId: streamId,
            message: RtmpCommandMessage(
                streamId: messageStreamId,
                transactionId: transactionId,
                objectEncoding: .amf0,
                commandName: "_result",
                commandObject: nil,
                arguments: [
                    1,
                ]
            )
        ))
    }

    private func processMessageAmf0CommandDeleteStream(transactionId _: Int) {}

    private func processMessageAmf0CommandPublish(transactionId: Int, arguments: [Any?]) {
        guard let client else {
            return
        }
        guard arguments.count > 0 else {
            client.stopInternal(reason: "Missing publish argument")
            return
        }
        guard let streamKey = arguments[0] as? String else {
            client.stopInternal(reason: "Stream key not a string")
            return
        }
        let isStreamKeyConfigured: Bool
        if let stream = client.server?.settings.streams
            .filter({ !$0.streamKey.isEmpty })
            .first(where: { $0.streamKey == streamKey })
        {
            client.latency = stream.latency!
            client.cameraId = stream.id
            client
                .targetLatenciesSynchronizer =
                TargetLatenciesSynchronizer(targetLatency: Double(stream.latency!) / 1000.0)
            isStreamKeyConfigured = true
        } else {
            isStreamKeyConfigured = false
        }
        guard isStreamKeyConfigured else {
            client.stopInternal(reason: "Stream key \(streamKey) not configured")
            return
        }
        client.streamKey = streamKey
        client.connectionState = .connected
        client.server?.handleClientConnected(client: client)
        client.sendMessage(chunk: RtmpChunk(
            type: .zero,
            chunkStreamId: streamId,
            message: RtmpCommandMessage(
                streamId: messageStreamId,
                transactionId: transactionId,
                objectEncoding: .amf0,
                commandName: "onStatus",
                commandObject: nil,
                arguments: [
                    [
                        "level": "status",
                        "code": "NetStream.Publish.Start",
                        "description": "Start publishing.",
                    ],
                ]
            )
        ))
    }

    private func processMessageChunkSize() {
        guard let client else {
            return
        }
        guard messageBody.count == 4 else {
            client.stopInternal(reason: "Not 4 bytes chunk size")
            return
        }
        client.chunkSizeFromClient = Int(messageBody.getFourBytesBe())
        logger
            .info(
                "rtmp-server: client: Chunk size from client: \(client.chunkSizeFromClient)"
            )
    }

    private func processMessageWindowAck() {
        guard let client else {
            return
        }
        guard messageBody.count == 4 else {
            client.stopInternal(reason: "Not 4 bytes window acknowledgement size")
            return
        }
        client.windowAcknowledgementSize = Int(messageBody.getFourBytesBe())
        logger
            .info(
                "rtmp-server: client: Window acknowledgement size from client: \(client.windowAcknowledgementSize)"
            )
    }

    private func processMessageAudio() {
        guard let client else {
            return
        }
        guard messageBody.count >= 2 else {
            client.stopInternal(reason: "Got \(messageBody.count) bytes audio message, expected >= 2")
            return
        }
        let control = messageBody[0]
        guard let codec = FLVAudioCodec(rawValue: control >> 4),
              let soundRate = FLVSoundRate(rawValue: (control & 0x0C) >> 2),
              let soundSize = FLVSoundSize(rawValue: (control & 0x02) >> 1),
              let soundType = FLVSoundType(rawValue: control & 0x01)
        else {
            client.stopInternal(reason: "Failed to parse audio settings \(control)")
            return
        }
        guard codec == .aac else {
            // Make lint happy.
            print(soundRate, soundSize, soundType)
            client.stopInternal(reason: "Unsupported audio codec \(codec). Only AAC is supported.")
            return
        }
        switch FLVAACPacketType(rawValue: messageBody[1]) {
        case .seq:
            processMessageAudioTypeSeq(client: client, codec: codec)
        case .raw:
            processMessageAudioTypeRaw(client: client, codec: codec)
        default:
            break
        }
    }

    private func processMessageAudioTypeSeq(client _: RtmpServerClient, codec: FLVAudioCodec) {
        if let config =
            MpegTsAudioConfig(bytes: [UInt8](messageBody[codec.headerSize ..< messageBody.count]))
        {
            var streamDescription = config.audioStreamBasicDescription()
            logger.info("rtmp-server: client: \(streamDescription)")
            if let audioFormat = AVAudioFormat(streamDescription: &streamDescription) {
                logger.info("rtmp-server: client: \(audioFormat)")
                audioBuffer = AVAudioCompressedBuffer(
                    format: audioFormat,
                    packetCapacity: 1,
                    maximumPacketSize: 1024 * Int(audioFormat.channelCount)
                )
                pcmAudioFormat = AVAudioFormat(
                    commonFormat: .pcmFormatInt16,
                    sampleRate: audioFormat.sampleRate,
                    channels: audioFormat.channelCount,
                    interleaved: audioFormat.isInterleaved
                )
                guard let pcmAudioFormat else {
                    logger.info("rtmp-server: client: Failed to create PCM audio format")
                    return
                }
                audioDecoder = AVAudioConverter(from: audioFormat, to: pcmAudioFormat)
                if audioDecoder == nil {
                    logger.info("rtmp-server: client: Failed to create audio decdoer")
                }
            } else {
                logger.info("rtmp-server: client: Failed to create audio format")
                audioBuffer = nil
                audioDecoder = nil
            }
        }
    }

    private func processMessageAudioTypeRaw(client: RtmpServerClient, codec: FLVAudioCodec) {
        guard let audioBuffer else {
            return
        }
        let length = messageBody.count - codec.headerSize
        messageBody.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
            guard let baseAddress = buffer.baseAddress else {
                return
            }
            audioBuffer.packetDescriptions?.pointee = AudioStreamPacketDescription(
                mStartOffset: 0,
                mVariableFramesInPacket: 0,
                mDataByteSize: UInt32(length)
            )
            audioBuffer.packetCount = 1
            audioBuffer.byteLength = UInt32(length)
            audioBuffer.data.copyMemory(from: baseAddress.advanced(by: codec.headerSize), byteCount: length)
        }
        guard let audioDecoder, let pcmAudioFormat else {
            return
        }
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: pcmAudioFormat, frameCapacity: 1024) else {
            return
        }
        var error: NSError?
        audioDecoder.convert(to: outputBuffer, error: &error) { _, inputStatus in
            inputStatus.pointee = .haveData
            return self.audioBuffer
        }
        if let error {
            logger.info("rtmp-server: client: Error \(error)")
        } else if let sampleBuffer = makeAudioSampleBuffer(client: client, audioBuffer: outputBuffer) {
            client.targetLatenciesSynchronizer
                .setLatestAudioPresentationTimeStamp(sampleBuffer.presentationTimeStamp.seconds)
            client.updateTargetLatencies()
            if firstAudioBufferTimestamp == nil {
                firstAudioBufferTimestamp = .now
            }
            totalNumberOfAudioSamples += UInt64(sampleBuffer.dataBuffer?.dataLength ?? 0) / 2
            client.handleAudioBuffer(sampleBuffer: sampleBuffer)
        }
    }

    private func processMessageVideo() {
        guard let client else {
            return
        }
        guard messageBody.count >= 2 else {
            client.stopInternal(reason: "Got \(messageBody.count) bytes video message, expected >= 2")
            return
        }
        let control = messageBody[0]
        let frameType = control >> 4
        let isExVideoHeader = (frameType & 0x8) == 0
        guard isExVideoHeader else {
            client.stopInternal(reason: "Unsupported video frame type \(frameType)")
            return
        }
        guard let format = FLVVideoCodec(rawValue: control & 0xF) else {
            client.stopInternal(reason: "Unsupported video format \(control & 0xF)")
            return
        }
        guard format == .avc else {
            client.stopInternal(reason: "Unsupported video format \(format). Only AVC is supported.")
            return
        }
        switch FLVAVCPacketType(rawValue: messageBody[1]) {
        case .seq:
            processMessageVideoTypeSeq(client: client)
        case .nal:
            processMessageVideoTypeNal(client: client)
        default:
            client.stopInternal(reason: "Unsupported video AVC packet type \(messageBody[1])")
        }
    }

    private func processMessageVideoTypeSeq(client: RtmpServerClient) {
        guard messageBody.count >= FLVTagType.video.headerSize else {
            client
                .stopInternal(
                    reason: """
                    Got \(messageBody.count) bytes video message, \
                    expected >= \(FLVTagType.video.headerSize)
                    """
                )
            return
        }
        guard videoDecoder == nil else {
            return
        }
        var config = MpegTsVideoConfigAvc()
        config.data = messageBody.subdata(in: FLVTagType.video.headerSize ..< messageBody.count)
        let status = config.makeFormatDescription(&formatDescription)
        if status == noErr {
            videoDecoder = VideoCodec(lockQueue: videoCodecLockQueue)
            videoDecoder!.formatDescription = formatDescription
            videoDecoder!.delegate = self
            videoDecoder!.startRunning()
        } else {
            client.stopInternal(reason: "Format description error \(status)")
        }
    }

    private func processMessageVideoTypeNal(client: RtmpServerClient) {
        guard messageBody.count > 9 else {
            logger.info("rtmp-server: client: Dropping short packet with data \(messageBody.hexString())")
            return
        }
        if firstVideoFrameTimestamp == nil {
            firstVideoFrameTimestamp = .now
        }
        totalNumberOfVideoFrames += 1
        if let sampleBuffer = makeVideoSampleBuffer(client: client) {
            client.targetLatenciesSynchronizer
                .setLatestVideoPresentationTimeStamp(sampleBuffer.presentationTimeStamp.seconds)
            client.updateTargetLatencies()
            videoCodecLockQueue.async {
                self.videoDecoder?.decodeSampleBuffer(sampleBuffer)
            }
        }
    }

    private func makeVideoSampleBuffer(client: RtmpServerClient) -> CMSampleBuffer? {
        var compositionTime = Int32(data: [0] + messageBody[2 ..< 5]).bigEndian
        compositionTime <<= 8
        compositionTime /= 256
        var duration: Int64
        let delta = mediaTimestamp - videoTimestamp
        duration = Int64(delta)
        if isMessageType0 {
            if mediaTimestampZero == -1 {
                mediaTimestampZero = delta
            }
            duration -= Int64(videoTimestamp)
            videoTimestamp = delta - mediaTimestampZero
        } else {
            videoTimestamp += delta
        }
        let presentationTimeStamp = Int64(videoTimestamp + getBasePresentationTimeStamp(client)) +
            Int64(compositionTime + client.latency)
        let decodeTimeStamp = Int64(videoTimestamp + getBasePresentationTimeStamp(client)) + Int64(client.latency)
        var timing = CMSampleTimingInfo(
            duration: CMTimeMake(value: duration, timescale: 1000),
            presentationTimeStamp: CMTimeMake(value: presentationTimeStamp, timescale: 1000),
            decodeTimeStamp: CMTimeMake(value: decodeTimeStamp, timescale: 1000)
        )
        let isKeyFrame = (messageBody[0] >> 4) & 0b0111 == FLVFrameType.key.rawValue
        let blockBuffer = messageBody.makeBlockBuffer(advancedBy: FLVTagType.video.headerSize)
        var sampleBuffer: CMSampleBuffer?
        var sampleSize = blockBuffer?.dataLength ?? 0
        guard CMSampleBufferCreate(
            allocator: kCFAllocatorDefault,
            dataBuffer: blockBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: formatDescription,
            sampleCount: 1,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleSizeEntryCount: 1,
            sampleSizeArray: &sampleSize,
            sampleBufferOut: &sampleBuffer
        ) == noErr else {
            return nil
        }
        sampleBuffer?.isSync = isKeyFrame
        return sampleBuffer
    }

    private func makeAudioSampleBuffer(client: RtmpServerClient,
                                       audioBuffer: AVAudioPCMBuffer) -> CMSampleBuffer?
    {
        let delta = mediaTimestamp - audioTimestamp
        if isMessageType0 {
            if mediaTimestampZero == -1 {
                mediaTimestampZero = delta
            }
            audioTimestamp = delta - mediaTimestampZero
        } else {
            audioTimestamp += delta
        }
        let presentationTimeStamp = CMTimeMake(
            value: Int64(audioTimestamp + getBasePresentationTimeStamp(client)) + Int64(client.latency),
            timescale: 1000
        )
        return audioBuffer.makeSampleBuffer(presentationTimeStamp: presentationTimeStamp)
    }

    private func getBasePresentationTimeStamp(_ client: RtmpServerClient) -> Double {
        return client.getBasePresentationTimeStamp()
    }
}

extension RtmpServerChunkStream: VideoCodecDelegate {
    func videoCodecOutputFormat(_: VideoCodec, _: CMFormatDescription) {}

    func videoCodecOutputSampleBuffer(_: VideoCodec, _ sampleBuffer: CMSampleBuffer) {
        guard let client else {
            return
        }
        client.handleFrame(sampleBuffer: sampleBuffer)
    }
}
