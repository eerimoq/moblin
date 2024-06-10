import AVFoundation
import Foundation
import Network

class RtmpServerChunkStream {
    private var messageData: Data
    var messageLength: Int
    var messageTypeId: UInt8
    var messageTimestamp: UInt32
    var messageStreamId: UInt32
    var isMessageType0: Bool
    var extendedTimestampPresentInType3: Bool
    private weak var client: RtmpServerClient?
    private var streamId: UInt16
    private var audioTimestampZero: Double
    private var audioTimestamp: Double
    private var videoTimestampZero: Double
    private var videoTimestamp: Double
    private var formatDescription: CMVideoFormatDescription?
    private var videoDecoder: VideoCodec?
    private var numberOfFrames: UInt64 = 0
    private var numberOfSamples: UInt64 = 0
    private var videoCodecLockQueue = DispatchQueue(label: "com.eerimoq.Moblin.VideoCodec")
    private var audioBuffer: AVAudioCompressedBuffer?
    private var audioDecoder: AVAudioConverter?
    private var pcmAudioFormat: AVAudioFormat?

    init(client: RtmpServerClient, streamId: UInt16) {
        self.client = client
        self.streamId = streamId
        messageData = Data()
        messageLength = 0
        messageTypeId = 0
        messageTimestamp = 0
        messageStreamId = 0
        audioTimestampZero = -1
        audioTimestamp = 0
        videoTimestampZero = -1
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

    func handleData(data: Data) {
        messageData += data
        // logger.info("rtmp-server: client: Got \(data.count) chunk data and \(messageRemain()) remain")
        if messageRemain() == 0 {
            processMessage()
            messageData.removeAll(keepingCapacity: true)
        }
    }

    private func messageRemain() -> Int {
        return messageLength - messageData.count
    }

    private func processMessage() {
        guard let messageType = RTMPMessageType(rawValue: messageTypeId) else {
            logger.info("rtmp-server: client: Bad message type \(messageTypeId)")
            return
        }
        // logger.info("rtmp-server: client: Processing message \(messageType)")
        switch messageType {
        case .amf0Command:
            processMessageAmf0Command()
        case .amf0Data:
            processMessageAmf0Data()
        case .chunkSize:
            processMessageChunkSize()
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
        let amf0 = AMF0Serializer(data: messageData)
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
        client.sendMessage(chunk: RTMPChunk(
            type: .zero,
            streamId: streamId,
            message: RTMPWindowAcknowledgementSizeMessage(2_500_000)
        ))
        client.sendMessage(chunk: RTMPChunk(
            type: .zero,
            streamId: streamId,
            message: RTMPSetPeerBandwidthMessage(size: 2_500_000, limit: .dynamic)
        ))
        client.sendMessage(chunk: RTMPChunk(
            type: .zero,
            streamId: streamId,
            message: RTMPSetChunkSizeMessage(1024)
        ))
        client.sendMessage(chunk: RTMPChunk(
            type: .zero,
            streamId: streamId,
            message: RTMPCommandMessage(
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
        client.sendMessage(chunk: RTMPChunk(
            type: .zero,
            streamId: streamId,
            message: RTMPCommandMessage(
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
        let isStreamKeyConfigured = DispatchQueue.main.sync {
            if let stream = client.server?.settings.streams.first(where: { stream in
                stream.streamKey == streamKey
            }) {
                client.fps = stream.fps!
                client.buggedPublisher = stream.buggedPublisher!
                client.manualFps = stream.manualFps!
                return true
            } else {
                return false
            }
        }
        guard isStreamKeyConfigured else {
            client.stopInternal(reason: "Stream key \(streamKey) not configured")
            return
        }
        client.streamKey = streamKey
        client.connectionState = .connected
        client.server?.handleClientConnected(client: client)
        client.sendMessage(chunk: RTMPChunk(
            type: .zero,
            streamId: streamId,
            message: RTMPCommandMessage(
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
        guard messageData.count == 4 else {
            client.stopInternal(reason: "Not 4 bytes chunk size")
            return
        }
        client.chunkSizeFromClient = Int(messageData.getFourBytesBe())
        logger
            .info(
                "rtmp-server: client: Chunk size from client: \(client.chunkSizeFromClient)"
            )
    }

    private func processMessageAudio() {
        guard let client else {
            return
        }
        guard messageData.count >= 2 else {
            client.stopInternal(reason: "Got \(messageData.count) bytes audio message, expected >= 2")
            return
        }
        let control = messageData[0]
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
            client.stopInternal(reason: "Unsupported audio codec \(codec)")
            return
        }
        switch FLVAACPacketType(rawValue: messageData[1]) {
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
            MpegTsAudioConfig(bytes: [UInt8](messageData[codec.headerSize ..< messageData.count]))
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
        let length = messageData.count - codec.headerSize
        messageData.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
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
        } else {
            let sampleBuffer = makeAudioSampleBuffer(client: client, audioBuffer: outputBuffer)
            if sampleBuffer != nil {
                client.handleAudioBuffer(sampleBuffer: sampleBuffer!)
            }
        }
    }

    private func processMessageVideo() {
        guard let client else {
            return
        }
        guard messageData.count >= 2 else {
            client.stopInternal(reason: "Got \(messageData.count) bytes video message, expected >= 2")
            return
        }
        let control = messageData[0]
        let frameType = control >> 4
        guard (frameType & 0x8) == 0 else {
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
        switch FLVAVCPacketType(rawValue: messageData[1]) {
        case .seq:
            processMessageVideoTypeSeq(client: client)
        case .nal:
            processMessageVideoTypeNal(client: client)
        default:
            client.stopInternal(reason: "Unsupported video AVC packet type \(messageData[1])")
        }
    }

    private func processMessageVideoTypeSeq(client: RtmpServerClient) {
        guard messageData.count >= FLVTagType.video.headerSize else {
            client
                .stopInternal(
                    reason: """
                    Got \(messageData.count) bytes video message, \
                    expected >= \(FLVTagType.video.headerSize)
                    """
                )
            return
        }
        guard videoDecoder == nil else {
            return
        }
        var config = MpegTsVideoConfigAvc()
        config.data = messageData.subdata(in: FLVTagType.video.headerSize ..< messageData.count)
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
        guard messageData.count > 9 else {
            logger.info("rtmp-server: client: Dropping short packet with data \(messageData.hexString())")
            return
        }
        if let sampleBuffer = makeVideoSampleBuffer(client: client) {
            videoDecoder?.appendSampleBuffer(sampleBuffer)
        } else {
            client.stopInternal(reason: "Make sample buffer failed")
        }
    }

    private func makeVideoSampleBuffer(client: RtmpServerClient) -> CMSampleBuffer? {
        var presentationTimeStamp: Int64
        var decodeTimeStamp: Int64
        var duration: Int64
        var compositionTime = Int32(data: [0] + messageData[2 ..< 5]).bigEndian
        compositionTime <<= 8
        compositionTime /= 256
        if client.buggedPublisher {
            // for now static fps
            duration = Int64(1000 / 30)
            videoTimestamp = Double(numberOfFrames) / 30 * 1000
            numberOfFrames += 1
        } else {
            duration = Int64(messageTimestamp)
            if isMessageType0 {
                if videoTimestampZero == -1 {
                    videoTimestampZero = Double(messageTimestamp)
                }
                duration -= Int64(videoTimestamp)
                videoTimestamp = Double(messageTimestamp) - videoTimestampZero
            } else {
                videoTimestamp += Double(messageTimestamp)
            }
        }
        presentationTimeStamp = Int64(videoTimestamp) + Int64(compositionTime)
        decodeTimeStamp = Int64(videoTimestamp)
        var timing = CMSampleTimingInfo(
            duration: CMTimeMake(value: duration, timescale: 1000),
            presentationTimeStamp: CMTimeMake(value: presentationTimeStamp, timescale: 1000),
            decodeTimeStamp: CMTimeMake(value: decodeTimeStamp, timescale: 1000)
        )
        /* logger.info("""
         rtmp-server: client: Created sample buffer \
         MTS: \(messageTimestamp * messageTimestampScaling) \
         CT: \(compositionTime) \
         DUR: \(timing.duration.seconds), \
         PTS: \(timing.presentationTimeStamp.seconds), \
         DTS: \(timing.decodeTimeStamp.seconds)
         """) */
        let blockBuffer = messageData.makeBlockBuffer(advancedBy: FLVTagType.video.headerSize)
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
        sampleBuffer?.isKeyFrame = messageData[0] >> 4 & 0b0111 == FLVFrameType.key.rawValue
        return sampleBuffer
    }

    private func makeAudioSampleBuffer(client: RtmpServerClient,
                                       audioBuffer: AVAudioPCMBuffer) -> CMSampleBuffer?
    {
        if client.buggedPublisher {
            audioTimestamp = Double(numberOfSamples) /
                (audioBuffer.format.sampleRate / Double(audioBuffer.frameLength)) * 1000

            numberOfSamples += 1
        } else {
            if isMessageType0 {
                if audioTimestampZero == -1 {
                    audioTimestampZero = Double(messageTimestamp)
                }
                audioTimestamp = Double(messageTimestamp) - audioTimestampZero
            } else {
                audioTimestamp += Double(messageTimestamp)
            }
        }
        let presentationTimeStamp = CMTimeMake(value: Int64(audioTimestamp), timescale: 1000)
        /* logger.info("""
         rtmp-server: client: Created audio sample buffer \
         MTS: \(messageTimestamp * messageTimestampScaling) \
         DUR: \(timing.duration.seconds), \
         PTS: \(timing.presentationTimeStamp.seconds), \
         DTS: \(timing.decodeTimeStamp.seconds)
         """) */
        return audioBuffer.makeSampleBuffer(presentationTimeStamp: presentationTimeStamp)
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
