import AVFoundation
import Foundation
import Network

class RtmpServerChunkStream {
    private var messageBody: Data
    var messageLength: Int
    var messageTypeId: UInt8
    var messageTimestamp: UInt32
    var messageStreamId: UInt32
    var isAbsoluteTimeStamp: Bool
    var extendedTimestampPresentInType3: Bool
    private weak var client: RtmpServerClient?
    private var streamId: UInt16
    private var mediaTimestamp: Double = 0
    private var mediaTimestampZero: Double
    private var videoTimestamp: Double
    private var formatDescription: CMVideoFormatDescription?
    private var videoDecoder: VideoDecoder?
    private var audioBuffer: AVAudioCompressedBuffer?
    private var audioDecoder: AVAudioConverter?
    private var pcmAudioFormat: AVAudioFormat?
    private var pcmAudioBuffer: AVAudioPCMBuffer?

    init(client: RtmpServerClient, streamId: UInt16) {
        self.client = client
        self.streamId = streamId
        messageBody = Data()
        messageLength = 0
        messageTypeId = 0
        messageTimestamp = 0
        messageStreamId = 0
        mediaTimestampZero = -1
        videoTimestamp = -1
        isAbsoluteTimeStamp = true
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

    private func messageRemain() -> Int {
        return messageLength - messageBody.count
    }

    private func processMessage() {
        guard let messageType = RtmpMessageType(rawValue: messageTypeId) else {
            logger.info("rtmp-server: client: Bad message type \(messageTypeId)")
            return
        }
        if isAbsoluteTimeStamp {
            mediaTimestamp = Double(messageTimestamp)
        } else {
            mediaTimestamp += Double(messageTimestamp)
        }
        if mediaTimestampZero == -1 {
            mediaTimestampZero = mediaTimestamp
        }
        // logger.info("""
        //             rtmp-server: client: Processing message \(messageType) \
        //             \(isAbsoluteTimeStamp) \(messageTimestamp)
        //             """)
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
        let amf0 = Amf0Deserializer(data: messageBody)
        let commandName: RtmpCommandName
        let transactionId: Int
        let commandObject: AsObject
        var arguments: [Any?]
        do {
            commandName = try RtmpCommandName(rawValue: amf0.deserializeString()) ?? .unknown
            transactionId = try amf0.deserializeInt()
            commandObject = try amf0.deserializeAsObject()
            arguments = []
            if amf0.bytesAvailable > 0 {
                try arguments.append(amf0.deserialize())
            }
        } catch {
            client.stopInternal(reason: "AMF-0 decode error \(error)")
            return
        }
        switch commandName {
        case .connect:
            processMessageAmf0CommandConnect(transactionId: transactionId, commandObject: commandObject)
        case .fcPublish:
            processMessageAmf0CommandFCPublish(transactionId: transactionId)
        case .fcUnpublish:
            processMessageAmf0CommandFCUnpublish(transactionId: transactionId)
        case .createStream:
            processMessageAmf0CommandCreateStream(transactionId: transactionId)
        case .deleteStream:
            processMessageAmf0CommandDeleteStream(transactionId: transactionId)
        case .publish:
            processMessageAmf0CommandPublish(transactionId: transactionId, arguments: arguments)
        default:
            logger.info("rtmp-server: client: Unsupported command \(commandName)")
        }
    }

    private func processMessageAmf0Data() {
        logger.info("rtmp-server: client: Ignoring AMF-0 data")
    }

    private func processMessageAmf0CommandConnect(transactionId: Int, commandObject: AsObject) {
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
                commandType: .amf0Command,
                commandName: .result,
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
        client?.sendMessage(chunk: RtmpChunk(
            type: .zero,
            chunkStreamId: streamId,
            message: RtmpCommandMessage(
                streamId: messageStreamId,
                transactionId: transactionId,
                commandType: .amf0Command,
                commandName: .result,
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
            client.latency = stream.latency
            client.cameraId = stream.id
            client
                .targetLatenciesSynchronizer =
                TargetLatenciesSynchronizer(targetLatency: Double(stream.latency) / 1000.0)
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
                commandType: .amf0Command,
                commandName: .onStatus,
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
        logger.info("rtmp-server: client: Chunk size from client: \(client.chunkSizeFromClient)")
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
        guard checkMessageBodyBigEnough(client: client, minimumSize: 2) else {
            return
        }
        let control = messageBody[0]
        guard let codec = FlvAudioCodec(rawValue: control >> 4) else {
            client.stopInternal(reason: "Failed to parse audio settings \(control)")
            return
        }
        guard codec == .aac else {
            client.stopInternal(reason: "Unsupported audio codec \(codec). Only AAC is supported.")
            return
        }
        guard FlvSoundRate(rawValue: (control & 0x0C) >> 2) != nil,
              FlvSoundSize(rawValue: (control & 0x02) >> 1) != nil,
              FlvSoundType(rawValue: control & 0x01) != nil
        else {
            client.stopInternal(reason: "Failed to parse audio settings \(control)")
            return
        }
        switch FlvAacPacketType(rawValue: messageBody[1]) {
        case .seq:
            processMessageAudioTypeSeq(client: client, codec: codec)
        case .raw:
            processMessageAudioTypeRaw(client: client, codec: codec)
        default:
            break
        }
    }

    private func processMessageAudioTypeSeq(client _: RtmpServerClient, codec: FlvAudioCodec) {
        guard let config = MpegTsAudioConfig(data: [UInt8](messageBody[codec.headerSize ..< messageBody.count])) else {
            return
        }
        var streamDescription = config.audioStreamBasicDescription()
        logger.info("rtmp-server: client: \(streamDescription)")
        guard let audioFormat = AVAudioFormat(streamDescription: &streamDescription) else {
            logger.info("rtmp-server: client: Failed to create audio format")
            audioBuffer = nil
            audioDecoder = nil
            return
        }
        logger.info("rtmp-server: client: \(audioFormat)")
        audioBuffer = AVAudioCompressedBuffer(
            format: audioFormat,
            packetCapacity: 1,
            maximumPacketSize: 4096 * Int(audioFormat.channelCount)
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
        pcmAudioBuffer = AVAudioPCMBuffer(pcmFormat: pcmAudioFormat, frameCapacity: 1024)
        guard pcmAudioBuffer != nil else {
            logger.info("rtmp-server: client: Failed to create PCM audio buffer")
            return
        }
        audioDecoder = AVAudioConverter(from: audioFormat, to: pcmAudioFormat)
        if audioDecoder == nil {
            logger.info("rtmp-server: client: Failed to create audio decdoer")
        }
    }

    private func processMessageAudioTypeRaw(client: RtmpServerClient, codec: FlvAudioCodec) {
        guard let audioBuffer else {
            return
        }
        let length = messageBody.count - codec.headerSize
        guard length > 0 else {
            return
        }
        guard length <= audioBuffer.maximumPacketSize else {
            logger.info("rtmp-server: Audio packet too long (\(length) > \(audioBuffer.maximumPacketSize))")
            return
        }
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
        guard let audioDecoder, let pcmAudioBuffer else {
            return
        }
        var error: NSError?
        audioDecoder.convert(to: pcmAudioBuffer, error: &error) { _, inputStatus in
            inputStatus.pointee = .haveData
            return self.audioBuffer
        }
        if let error {
            logger.info("rtmp-server: client: Audio decode error of packet with length \(length): \(error)")
            return
        }
        guard let sampleBuffer = makeAudioSampleBuffer(client: client, audioBuffer: pcmAudioBuffer) else {
            return
        }
        client.targetLatenciesSynchronizer
            .setLatestAudioPresentationTimeStamp(sampleBuffer.presentationTimeStamp.seconds)
        client.updateTargetLatencies()
        client.handleAudioBuffer(sampleBuffer: sampleBuffer)
    }

    private func processMessageVideo() {
        guard let client, checkMessageBodyBigEnough(client: client, minimumSize: 2) else {
            return
        }
        let control = messageBody[0]
        let isExVideoHeader = (control & extendedVideoHeader) == extendedVideoHeader
        if isExVideoHeader {
            processMessageVideoExtendedHeader(client: client, control: control)
        } else {
            processMessageVideoDefaultHeader(client: client, control: control)
        }
    }

    private func processMessageVideoDefaultHeader(client: RtmpServerClient, control: UInt8) {
        guard let format = FlvVideoCodec(rawValue: control & 0xF) else {
            client.stopInternal(reason: "Unsupported video codec \(control & 0xF)")
            return
        }
        guard format == .avc else {
            client.stopInternal(reason: "Unsupported video codec \(format.toString()).")
            return
        }
        switch FlvAvcPacketType(rawValue: messageBody[1]) {
        case .seq:
            processMessageVideoTypeSeq(client: client)
        case .nal:
            processMessageVideoTypeNal(client: client)
        default:
            logger.info("rtmp-server: Unsupported video H.264/AVC packet type \(messageBody[1])")
        }
    }

    private func processMessageVideoExtendedHeader(client: RtmpServerClient, control: UInt8) {
        guard checkMessageBodyBigEnough(client: client, minimumSize: 5) else {
            return
        }
        let frameType = (control >> 4) & 0b111
        guard let videoType = FlvFrameType(rawValue: frameType) else {
            client.stopInternal(reason: "Unsupported video frame type \(frameType)")
            return
        }
        let packetType = control & 0b1111
        guard let packetType = FlvVideoPacketType(rawValue: packetType) else {
            client.stopInternal(reason: "Unsupported video packet type \(packetType)")
            return
        }
        let fourCc = UInt32(messageBody[1]) << 24
            | UInt32(messageBody[2]) << 16
            | UInt32(messageBody[3]) << 8
            | UInt32(messageBody[4]) << 0
        guard let fourCc = FlvVideoFourCC(rawValue: fourCc) else {
            client.stopInternal(reason: "Unsupported fourCC \(fourCc)")
            return
        }
        guard fourCc == .hevc else {
            client.stopInternal(reason: "Unsupported fourCC \(fourCc).")
            return
        }
        switch packetType {
        case .sequenceStart:
            processMessageVideoTypeSequenceStart(client: client)
        case .codedFrames:
            processMessageVideoTypeCodedFrames(client: client, isKeyFrame: videoType == .key)
        case .sequenceEnd:
            client.stopInternal(reason: "Stream ended")
        case .codedFramesX:
            processMessageVideoTypeCodedFramesX(client: client, isKeyFrame: videoType == .key)
        default:
            logger.info("rtmp-server: Unsupported video packet type \(packetType)")
        }
    }

    private func processMessageVideoTypeSeq(client: RtmpServerClient) {
        guard checkMessageBodyBigEnough(client: client, minimumSize: FlvTagType.video.headerSize) else {
            return
        }
        let avcC = messageBody.subdata(in: FlvTagType.video.headerSize ..< messageBody.count)
        let videoConfig = MpegTsVideoConfigAvc(avcC: avcC)
        let status = videoConfig.makeFormatDescription(&formatDescription)
        if status == noErr {
            setupVideoEncoderIfNeeded(formatDescription: formatDescription)
        } else {
            client.stopInternal(reason: "H.264/AVC format description error \(status)")
        }
    }

    private func processMessageVideoTypeSequenceStart(client: RtmpServerClient) {
        guard checkMessageBodyBigEnough(client: client, minimumSize: FlvTagType.video.headerSize) else {
            return
        }
        let hvcC = messageBody.subdata(in: FlvTagType.video.headerSize ..< messageBody.count)
        let videoConfig = MpegTsVideoConfigHevc(hvcC: hvcC)
        let status = videoConfig.makeFormatDescription(&formatDescription)
        if status == noErr {
            setupVideoEncoderIfNeeded(formatDescription: formatDescription)
        } else {
            client.stopInternal(reason: "H.265/HEVC format description error \(status)")
        }
    }

    private func setupVideoEncoderIfNeeded(formatDescription: CMFormatDescription?) {
        guard videoDecoder == nil else {
            return
        }
        videoDecoder = VideoDecoder(lockQueue: rtmpServerDispatchQueue)
        videoDecoder?.delegate = self
        videoDecoder?.startRunning(formatDescription: formatDescription)
    }

    private func processMessageVideoTypeNal(client: RtmpServerClient) {
        guard messageBody.count > 9 else {
            logger.info("rtmp-server: client: Dropping short packet with data \(messageBody.hexString())")
            return
        }
        let isKeyFrame = (messageBody[0] >> 4) & 0b0111 == FlvFrameType.key.rawValue
        processMessageVideoFrame(client: client,
                                 isKeyFrame: isKeyFrame,
                                 compositionTime: calcCompositionTime(offset: 2),
                                 dataOffset: FlvTagType.video.headerSize)
    }

    private func processMessageVideoTypeCodedFrames(client: RtmpServerClient, isKeyFrame: Bool) {
        guard messageBody.count > 9 else {
            logger.info("rtmp-server: client: Dropping short packet with data \(messageBody.hexString())")
            return
        }
        processMessageVideoFrame(client: client,
                                 isKeyFrame: isKeyFrame,
                                 compositionTime: calcCompositionTime(offset: 5),
                                 dataOffset: FlvTagType.video.headerSize + 3)
    }

    private func calcCompositionTime(offset: Int) -> Int32 {
        var compositionTime = Int32(data: [0] + messageBody[offset ..< offset + 3]).bigEndian
        compositionTime <<= 8
        compositionTime /= 256
        return compositionTime
    }

    private func processMessageVideoTypeCodedFramesX(client: RtmpServerClient, isKeyFrame: Bool) {
        processMessageVideoFrame(client: client,
                                 isKeyFrame: isKeyFrame,
                                 compositionTime: 0,
                                 dataOffset: FlvTagType.video.headerSize)
    }

    private func processMessageVideoFrame(client: RtmpServerClient,
                                          isKeyFrame: Bool,
                                          compositionTime: Int32,
                                          dataOffset: Int)
    {
        guard let sampleBuffer = makeVideoSampleBuffer(client: client,
                                                       isKeyFrame: isKeyFrame,
                                                       compositionTime: compositionTime,
                                                       dataOffset: dataOffset)
        else {
            return
        }
        client.targetLatenciesSynchronizer
            .setLatestVideoPresentationTimeStamp(sampleBuffer.presentationTimeStamp.seconds)
        client.updateTargetLatencies()
        videoDecoder?.decodeSampleBuffer(sampleBuffer)
    }

    private func makeVideoSampleBuffer(client: RtmpServerClient,
                                       isKeyFrame: Bool,
                                       compositionTime: Int32,
                                       dataOffset: Int) -> CMSampleBuffer?
    {
        var duration: Int64
        if videoTimestamp == -1 {
            duration = 0
        } else {
            duration = Int64(mediaTimestamp - videoTimestamp)
        }
        videoTimestamp = mediaTimestamp - mediaTimestampZero
        let presentationTimeStamp = Int64(videoTimestamp + getBasePresentationTimeStamp(client)) +
            Int64(compositionTime + client.latency)
        let decodeTimeStamp = Int64(videoTimestamp + getBasePresentationTimeStamp(client)) + Int64(client.latency)
        var timing = CMSampleTimingInfo(
            duration: CMTimeMake(value: duration, timescale: 1000),
            presentationTimeStamp: CMTimeMake(value: presentationTimeStamp, timescale: 1000),
            decodeTimeStamp: CMTimeMake(value: decodeTimeStamp, timescale: 1000)
        )
        let blockBuffer = messageBody.makeBlockBuffer(advancedBy: dataOffset)
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
        sampleBuffer?.setIsSync(isKeyFrame)
        return sampleBuffer
    }

    private func makeAudioSampleBuffer(client: RtmpServerClient, audioBuffer: AVAudioPCMBuffer) -> CMSampleBuffer? {
        let audioTimestamp = mediaTimestamp - mediaTimestampZero
        let presentationTimeStamp = CMTimeMake(
            value: Int64(audioTimestamp + getBasePresentationTimeStamp(client)) + Int64(client.latency),
            timescale: 1000
        )
        return audioBuffer.makeSampleBuffer(presentationTimeStamp)
    }

    private func getBasePresentationTimeStamp(_ client: RtmpServerClient) -> Double {
        return client.getBasePresentationTimeStamp()
    }

    private func checkMessageBodyBigEnough(client: RtmpServerClient, minimumSize: Int) -> Bool {
        if messageBody.count < minimumSize {
            client.stopInternal(reason: "Got \(messageBody.count) bytes message, expected >= \(minimumSize)")
            return false
        }
        return true
    }
}

extension RtmpServerChunkStream: VideoDecoderDelegate {
    func videoDecoderOutputSampleBuffer(_: VideoDecoder, _ sampleBuffer: CMSampleBuffer) {
        client?.handleFrame(sampleBuffer: sampleBuffer)
    }
}
