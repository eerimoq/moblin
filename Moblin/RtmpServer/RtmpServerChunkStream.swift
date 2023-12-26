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
    private var client: RtmpServerClient!
    private var videoTimestampZero: Double
    private var videoTimestamp: Double
    private var isMessageType0: Bool
    private var formatDescription: CMVideoFormatDescription?
    private var videoCodec: VideoCodec

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
        videoCodec = VideoCodec()
    }

    func stop() {
        videoCodec.stopRunning()
        client = nil
    }

    func handleType0(messageTypeId: UInt8, messageLength: Int, messageTimestamp: UInt32) -> Int {
        self.messageTypeId = messageTypeId
        self.messageLength = messageLength
        self.messageTimestamp = messageTimestamp
        isMessageType0 = true
        return min(client.chunkSizeFromClient, messageRemain())
    }

    func handleType1(messageTypeId: UInt8, messageLength: Int, messageTimestamp: UInt32) -> Int {
        self.messageTypeId = messageTypeId
        self.messageLength = messageLength
        self.messageTimestamp = messageTimestamp
        isMessageType0 = false
        return min(client.chunkSizeFromClient, messageRemain())
    }

    func handleType2(messageTimestamp: UInt32) -> Int {
        self.messageTimestamp = messageTimestamp
        isMessageType0 = false
        return min(client.chunkSizeFromClient, messageRemain())
    }

    func handleType3() -> Int {
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
        let amf0 = AMF0Serializer(data: messageData)
        let commandName: String
        let transactionId: Int
        do {
            commandName = try amf0.deserialize()
            transactionId = try amf0.deserialize()
            let commandObject: ASObject = try amf0.deserialize()
            var arguments: [Any?] = []
            if amf0.bytesAvailable > 0 {
                try arguments.append(amf0.deserialize())
            }
            logger.info("""
            rtmp-server: client: \(chunkStreamId): Command: \(commandName), Object: \(commandObject), \
            Arguments: \(arguments)
            """)
        } catch {
            logger.info("rtmp-server: \(chunkStreamId): client: AMF-0 decode error \(error)")
            return
        }
        switch commandName {
        case "connect":
            processMessageAmf0CommandConnect(transactionId: transactionId)
        case "FCPublish":
            processMessageAmf0CommandFCPublish(transactionId: transactionId)
        case "FCUnpublish":
            processMessageAmf0CommandFCUnpublish(transactionId: transactionId)
        case "createStream":
            processMessageAmf0CommandCreateStream(transactionId: transactionId)
        case "deleteStream":
            processMessageAmf0CommandDeleteStream(transactionId: transactionId)
        case "publish":
            processMessageAmf0CommandPublish(transactionId: transactionId)
        default:
            logger.info("rtmp-server: client: \(chunkStreamId): Unsupported command \(commandName)")
        }
    }

    private func processMessageAmf0Data() {
        logger.info("rtmp-server: client: \(chunkStreamId): Ignoring AMF-0 data")
    }

    private func processMessageAmf0CommandConnect(transactionId: Int) {
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

    private func processMessageAmf0CommandPublish(transactionId: Int) {
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
        guard messageData.count == 4 else {
            return
        }
        client.chunkSizeFromClient = Int(messageData.getFourBytesBe())
        logger
            .info(
                "rtmp-server: client: \(chunkStreamId): Chunk size from client: \(client.chunkSizeFromClient)"
            )
    }

    private func processMessageVideo() {
        guard messageData.count > 1 else {
            return
        }
        let control = messageData[0]
        let frameType = control >> 4
        guard (frameType & 0x8) == 0 else {
            logger.info("rtmp-server: client: \(chunkStreamId): Unsupported video frame type \(frameType)")
            return
        }
        guard let format = FLVVideoCodec(rawValue: control & 0xF) else {
            logger.info("rtmp-server: client: \(chunkStreamId): Unsupported video format \(control & 0xF)")
            return
        }
        guard format == .avc else {
            logger.info("""
            rtmp-server: client: \(chunkStreamId): Unsupported video \
            format \(format). Only AVC is supported.
            """)
            return
        }
        switch FLVAVCPacketType(rawValue: messageData[1]) {
        case .seq:
            var config = AVCDecoderConfigurationRecord()
            config.data = messageData.subdata(in: FLVTagType.video.headerSize ..< messageData.count)
            let status = config.makeFormatDescription(&formatDescription)
            if status == noErr {
                videoCodec.formatDescription = formatDescription
                logger
                    .info(
                        "rtmp-server: client: \(chunkStreamId): Dimensions: \(formatDescription!.dimensions)"
                    )
                videoCodec.delegate = self
                videoCodec.startRunning()
            } else {
                logger.info("rtmp-server: client: \(chunkStreamId): Format description error \(status)")
            }
        case .nal:
            if let sampleBuffer = makeSampleBuffer() {
                /* logger.info("""
                 rtmp-server: client: \(chunkStreamId): Created sample buffer \
                 Size: \(sampleBuffer.totalSampleSize) \
                 PTS: \(sampleBuffer.presentationTimeStamp.seconds), \
                 DTS: \(sampleBuffer.decodeTimeStamp.seconds)
                 """) */
                videoCodec.appendSampleBuffer(sampleBuffer)
            } else {
                logger.info("rtmp-server: client: Make sample buffer failed")
            }
        default:
            logger.info("""
            rtmp-server: client: \(chunkStreamId): Unsupported video AVC packet type \(messageData[1])
            """)
        }
    }

    private func makeSampleBuffer() -> CMSampleBuffer? {
        var compositionTime = Int32(data: [0] + messageData[2 ..< 5]).bigEndian
        compositionTime <<= 8
        compositionTime /= 256
        var duration = Int64(messageTimestamp)
        if isMessageType0 {
            if videoTimestampZero == -1 {
                videoTimestampZero = Double(messageTimestamp)
            }
            duration -= Int64(videoTimestamp)
            videoTimestamp = Double(messageTimestamp) - videoTimestampZero
        } else {
            videoTimestamp += Double(messageTimestamp)
        }
        var timing = CMSampleTimingInfo(
            duration: CMTimeMake(value: duration, timescale: 1000),
            presentationTimeStamp: CMTimeMake(
                value: Int64(videoTimestamp) + Int64(compositionTime),
                timescale: 1000
            ),
            decodeTimeStamp: compositionTime == 0 ? .invalid : CMTimeMake(
                value: Int64(videoTimestamp),
                timescale: 1000
            )
        )
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
        // logger.info("rtmp-server: client: Codec did output sample buffer")
        client.onFrame?(sampleBuffer)
    }

    func videoCodec(_: HaishinKit.VideoCodec, errorOccurred error: HaishinKit.VideoCodec.Error) {
        logger.info("rtmp-server: client: Codec error \(error)")
    }

    func videoCodecWillDropFame(_: HaishinKit.VideoCodec) -> Bool {
        return false
    }
}
