import AVFoundation
import Foundation
import HaishinKit
import Network

class RtmpServerChunkStream: VideoCodecDelegate {
    private var messageData: Data
    private var messageLength: Int
    private var messageTypeId: UInt8
    private var chunkStreamId: UInt32
    private var messageTimestamp: UInt32
    private weak var client: RtmpServerClient?
    private var videoTimestampZero: Double
    private var videoTimestamp: Double
    private var isMessageType0: Bool
    private var formatDescription: CMVideoFormatDescription?
    private var videoCodec: VideoCodec?

    init(client: RtmpServerClient, chunkStreamId: UInt32) {
        self.client = client
        self.chunkStreamId = chunkStreamId
        messageData = Data()
        messageLength = 0
        messageTypeId = 0
        messageTimestamp = 0
        videoTimestampZero = -1
        videoTimestamp = 0
        isMessageType0 = true
    }

    func stop() {
        videoCodec?.stopRunning()
        videoCodec = nil
        client = nil
    }

    func handleType0(messageTypeId: UInt8, messageLength: Int, messageTimestamp: UInt32) -> Int {
        guard let client else {
            return 0
        }
        self.messageTypeId = messageTypeId
        self.messageLength = messageLength
        self.messageTimestamp = messageTimestamp
        isMessageType0 = true
        return min(client.chunkSizeFromClient, messageRemain())
    }

    func handleType1(messageTypeId: UInt8, messageLength: Int, messageTimestamp: UInt32) -> Int {
        guard let client else {
            return 0
        }
        self.messageTypeId = messageTypeId
        self.messageLength = messageLength
        self.messageTimestamp = messageTimestamp
        isMessageType0 = false
        return min(client.chunkSizeFromClient, messageRemain())
    }

    func handleType2(messageTimestamp: UInt32) -> Int {
        guard let client else {
            return 0
        }
        self.messageTimestamp = messageTimestamp
        isMessageType0 = false
        return min(client.chunkSizeFromClient, messageRemain())
    }

    func handleType3() -> Int {
        guard let client else {
            return 0
        }
        isMessageType0 = false
        return min(client.chunkSizeFromClient, messageRemain())
    }

    func handleData(data: Data) {
        messageData += data
        // logger.info("rtmp-server: client: Got \(data.count) chunk data and \(messageRemain()) remain")
        if messageRemain() == 0 {
            processMessage()
            messageData.removeAll()
        }
    }

    private func messageRemain() -> Int {
        return messageLength - messageData.count
    }

    private func processMessage() {
        guard let messageType = RTMPMessageType(rawValue: messageTypeId) else {
            logger.info("rtmp-server: client: \(chunkStreamId): Bad message type \(messageTypeId)")
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
            logger.info("rtmp-server: client: \(chunkStreamId): Message type \(messageType) not supported")
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
             rtmp-server: client: \(chunkStreamId): Command: \(commandName), Object: \(commandObject), \
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
            logger.info("rtmp-server: client: \(chunkStreamId): Unsupported command \(commandName)")
        }
    }

    private func processMessageAmf0Data() {
        logger.info("rtmp-server: client: \(chunkStreamId): Ignoring AMF-0 data")
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
        guard url.path() == rtmpApp else {
            client.stopInternal(reason: "Not a camera path")
            return
        }
        client.sendMessage(chunk: RTMPChunk(
            type: .zero,
            streamId: UInt16(2),
            message: RTMPWindowAcknowledgementSizeMessage(2_500_000)
        ))
        client.sendMessage(chunk: RTMPChunk(
            type: .zero,
            streamId: UInt16(2),
            message: RTMPSetPeerBandwidthMessage(size: 2_500_000, limit: .dynamic)
        ))
        client.sendMessage(chunk: RTMPChunk(
            type: .zero,
            streamId: UInt16(2),
            message: RTMPSetChunkSizeMessage(1024)
        ))
        client.sendMessage(chunk: RTMPChunk(
            type: .zero,
            streamId: UInt16(2),
            message: RTMPCommandMessage(
                streamId: 3,
                transactionId: transactionId,
                objectEncoding: .amf0,
                commandName: "_result",
                commandObject: nil,
                arguments: []
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
            streamId: UInt16(2),
            message: RTMPCommandMessage(
                streamId: 3,
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
            client.server?.settings.streams.contains(where: { stream in
                stream.streamKey == streamKey
            }) == true
        }
        guard isStreamKeyConfigured else {
            client.stopInternal(reason: "Stream key \(streamKey) not configured")
            return
        }
        client.streamKey = streamKey
        logger.info("rtmp-server: client: Start stream key \(streamKey)")
        client.server?.onPublishStart(streamKey)
        client.server?.handleClientConnected(client: client)
        client.sendMessage(chunk: RTMPChunk(
            type: .zero,
            streamId: UInt16(2),
            message: RTMPCommandMessage(
                streamId: 3,
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
        /* logger
         .info(
             "rtmp-server: client: \(chunkStreamId): Chunk size from client: \(client?.chunkSizeFromClient ?? -1)"
         ) */
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
            if videoCodec == nil {
                var config = AVCDecoderConfigurationRecord()
                config.data = messageData.subdata(in: FLVTagType.video.headerSize ..< messageData.count)
                let status = config.makeFormatDescription(&formatDescription)
                if status == noErr {
                    videoCodec = VideoCodec()
                    videoCodec!.formatDescription = formatDescription
                    videoCodec!.delegate = self
                    videoCodec!.startRunning()
                } else {
                    client.stopInternal(reason: "Format description error \(status)")
                }
            }
        case .nal:
            guard messageData.count > 9 else {
                logger.info("rtmp-server: client: Dropping short packet with data \(messageData.hexString())")
                return
            }
            if let sampleBuffer = makeSampleBuffer() {
                videoCodec?.appendSampleBuffer(sampleBuffer)
            } else {
                client.stopInternal(reason: "Make sample buffer failed")
            }
        default:
            client.stopInternal(reason: "Unsupported video AVC packet type \(messageData[1])")
        }
    }

    private func makeSampleBuffer() -> CMSampleBuffer? {
        guard messageData.count >= FLVTagType.video.headerSize else {
            client?
                .stopInternal(
                    reason: "Got \(messageData.count) bytes video message, expected >= \(FLVTagType.video.headerSize)"
                )
            return nil
        }
        var compositionTime = Int32(data: [0] + messageData[2 ..< 5]).bigEndian
        compositionTime <<= 8
        compositionTime /= 256
        var duration = Int64(3 * messageTimestamp)
        if isMessageType0 {
            if videoTimestampZero == -1 {
                videoTimestampZero = Double(3 * messageTimestamp)
            }
            duration -= Int64(videoTimestamp)
            videoTimestamp = Double(3 * messageTimestamp) - videoTimestampZero
        } else {
            videoTimestamp += Double(3 * messageTimestamp)
        }
        var timing = CMSampleTimingInfo(
            duration: CMTimeMake(value: duration, timescale: 1000),
            presentationTimeStamp: CMTimeMake(
                value: Int64(videoTimestamp) + Int64(compositionTime),
                timescale: 1000
            ),
            decodeTimeStamp: CMTimeMake(
                value: Int64(videoTimestamp),
                timescale: 1000
            )
        )
        /* logger.info("""
         rtmp-server: client: \(chunkStreamId): Created sample buffer \
         MTS: \(3 * messageTimestamp) \
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
        sampleBuffer?.isNotSync = !(messageData[0] >> 4 & 0b0111 == FLVFrameType.key.rawValue)
        return sampleBuffer
    }

    private func processMessageAudio() {
        // logger.info("rtmp-server: client: Audio: \(messageData.count)")
    }
}

extension RtmpServerChunkStream {
    func videoCodec(_: HaishinKit.VideoCodec, didOutput _: CMFormatDescription?) {
        // logger.info("rtmp-server: client: Codec did output format description")
    }

    func videoCodec(_: HaishinKit.VideoCodec, didOutput sampleBuffer: CMSampleBuffer) {
        guard let client else {
            return
        }
        // logger.info("rtmp-server: client: Codec did output sample buffer")
        client.handleFrame(sampleBuffer: sampleBuffer)
    }

    func videoCodec(_: HaishinKit.VideoCodec, errorOccurred error: HaishinKit.VideoCodec.Error) {
        logger.info("rtmp-server: client: Codec error \(error)")
    }

    func videoCodecWillDropFame(_: HaishinKit.VideoCodec) -> Bool {
        return false
    }
}
