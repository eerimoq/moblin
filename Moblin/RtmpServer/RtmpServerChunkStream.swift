import Foundation
import HaishinKit
import Network

class RtmpServerChunkStream {
    private var messageData: Data
    private var messageLength: Int
    private var messageTypeId: UInt8
    private var chunkStreamId: UInt32
    private var client: RtmpServerClient!

    init(client: RtmpServerClient, chunkStreamId: UInt32) {
        self.client = client
        self.chunkStreamId = chunkStreamId
        messageData = Data()
        messageLength = 0
        messageTypeId = 0
    }

    func stop() {
        client = nil
    }

    func handleType0(messageTypeId: UInt8, messageLength: Int) -> Int {
        self.messageTypeId = messageTypeId
        self.messageLength = messageLength
        return min(client.chunkSizeFromClient, messageRemain())
    }

    func handleType1(messageTypeId: UInt8, messageLength: Int) -> Int {
        self.messageTypeId = messageTypeId
        self.messageLength = messageLength
        return min(client.chunkSizeFromClient, messageRemain())
    }

    func handleType2() -> Int {
        return min(client.chunkSizeFromClient, messageRemain())
    }

    func handleType3() -> Int {
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
            logger
                .info(
                    "rtmp-server: client: \(chunkStreamId): Unsupported video format \(format). Only AVC is supported."
                )
            return
        }
        switch FLVAVCPacketType(rawValue: messageData[1]) {
        case .seq:
            logger.info("rtmp-server: client: \(chunkStreamId): Make format description")
            var config = AVCDecoderConfigurationRecord()
            config.data = messageData.subdata(in: FLVTagType.video.headerSize ..< messageData.count)
        // status = config.makeFormatDescription(&stream.mixer.videoIO.formatDescription)
        case .nal:
            logger
                .info(
                    "rtmp-server: client: \(chunkStreamId): Make sample buffer of \(messageData.count) bytes"
                )
        /* if let sampleBuffer = makeSampleBuffer(stream, type: type, offset: 0) {
             stream.mixer.videoIO.codec.appendSampleBuffer(sampleBuffer)
         } */
        default:
            logger
                .info(
                    "rtmp-server: client: \(chunkStreamId): Unsupported video AVC packet type \(messageData[1])"
                )
        }
    }

    private func processMessageAudio() {
        // logger.info("rtmp-server: client: Audio: \(messageData.count)")
    }
}
