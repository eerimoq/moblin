import AVFAudio
import CoreMedia
import Foundation
import Network

private let rtmpVersion: UInt8 = 3

private enum ClientState {
    case uninitialized
    case versionSent
    case ackSent
    case handshakeDone
}

private enum ChunkState {
    case basicHeaderFirstByte
    case messageHeaderType0
    case messageHeaderType1
    case messageHeaderType2
    case extendedTimestamp
    case data
}

enum RtmpServerClientConnectionState {
    case idle
    case connecting
    case connected
}

class RtmpServerClient {
    private var connection: NWConnection
    private var state: ClientState
    private var chunkState: ChunkState
    private var chunkSizeToClient = 128
    var chunkSizeFromClient = 128
    var windowAcknowledgementSize = 2_500_000
    private var chunkStreams: [UInt16: RtmpServerChunkStream]
    private var chunkStream: RtmpServerChunkStream!
    var streamKey: String = ""
    weak var server: RtmpServer?
    var latestReceiveTime = ContinuousClock.now
    var connectionState: RtmpServerClientConnectionState {
        didSet {
            logger.info("rtmp-server: client: State change \(oldValue) -> \(connectionState)")
        }
    }

    private var totalBytesReceived: UInt64 = 0
    private var totalBytesReceivedAcked: UInt64 = 0
    var latency: Int32 = 2000

    init(server: RtmpServer, connection: NWConnection) {
        self.server = server
        self.connection = connection
        state = .uninitialized
        chunkState = .basicHeaderFirstByte
        chunkStreams = [:]
        connectionState = .idle
        connection.stateUpdateHandler = handleStateUpdate(to:)
        connection.start(queue: rtmpServerDispatchQueue)
    }

    func start() {
        state = .uninitialized
        chunkState = .basicHeaderFirstByte
        receiveData(size: 1 + 1536)
        connectionState = .connecting
    }

    func stop(reason: String) {
        logger.info("rtmp-server: client: Stopping with reason: \(reason)")
        for chunkStream in chunkStreams.values {
            chunkStream.stop()
        }
        chunkStreams.removeAll()
        connection.cancel()
        connectionState = .idle
    }

    func stopInternal(reason: String) {
        guard connectionState != .idle else {
            return
        }
        server?.handleClientDisconnected(client: self, reason: reason)
    }

    func getInfo() -> RtmpServerClientInfo {
        var audioSamplesPerSecond = 0.0
        var videoFps = 0.0
        for chunkStream in chunkStreams.values {
            let info = chunkStream.getInfo()
            if info.audioSamplesPerSecond != 0.0 {
                audioSamplesPerSecond = info.audioSamplesPerSecond
            }
            if info.videoFps != 0.0 {
                videoFps = info.videoFps
            }
        }
        return RtmpServerClientInfo(audioSamplesPerSecond: audioSamplesPerSecond, videoFps: videoFps)
    }

    private func handleStateUpdate(to _: NWConnection.State) {
        // logger.info("rtmp-server: client: Socket state change to \(state)")
    }

    func handleFrame(sampleBuffer: CMSampleBuffer) {
        server?.onFrame(streamKey, sampleBuffer)
    }

    func handleAudioBuffer(sampleBuffer: CMSampleBuffer) {
        server?.onAudioBuffer(streamKey, sampleBuffer)
    }

    private func handleData(data: Data) {
        switch state {
        case .uninitialized:
            handleDataUninitialized(data: data)
        case .versionSent:
            break
        case .ackSent:
            handleDataAckSent(data: data)
        case .handshakeDone:
            handleDataHandshakeDone(data: data)
        }
    }

    private func handleDataUninitialized(data: Data) {
        guard data.count == 1 + 1536 else {
            stopInternal(reason: "Wrong length \(data.count) in uninitialized")
            return
        }
        let version = data[0]
        guard version == rtmpVersion else {
            stopInternal(reason: "Only version 3 is supported, not \(version)")
            return
        }
        let s0 = Data([rtmpVersion])
        send(data: s0)
        var s1 = Data([0, 0, 0, 0, 0, 0, 0, 0])
        s1 += Data.random(length: 1528)
        send(data: s1)
        state = .versionSent
        var s2 = Data([data[1], data[2], data[3], data[4], 0, 0, 0, 0])
        s2 += data[9...]
        send(data: s2)
        receiveData(size: 1536)
        state = .ackSent
    }

    private func handleDataAckSent(data _: Data) {
        state = .handshakeDone
        receiveBasicHeaderFirstByte()
    }

    private func handleDataHandshakeDone(data: Data) {
        switch chunkState {
        case .basicHeaderFirstByte:
            handleDataHandshakeDoneBasicHeaderFirstByte(data: data)
        case .messageHeaderType0:
            handleDataHandshakeDoneMessageHeaderType0(data: data)
        case .messageHeaderType1:
            handleDataHandshakeDoneMessageHeaderType1(data: data)
        case .messageHeaderType2:
            handleDataHandshakeDoneMessageHeaderType2(data: data)
        case .extendedTimestamp:
            handleExtendedTimestamp(data: data)
        case .data:
            handleDataHandshakeDoneData(data: data)
        }
    }

    private func handleExtendedTimestamp(data: Data) {
        guard data.count == 4 else {
            stopInternal(reason: "Wrong length \(data.count) in extended timestamp")
            return
        }
        chunkStream.messageTimestamp = data.getUInt32Be()
        receiveChunkData()
    }

    private func handleDataHandshakeDoneBasicHeaderFirstByte(data: Data) {
        guard data.count == 1 else {
            stopInternal(reason: "Wrong length \(data.count) in basic header first byte")
            return
        }
        let firstByte = data[0]
        let format = firstByte >> 6
        let chunkStreamId = UInt16(firstByte & 0x3F)
        switch chunkStreamId {
        case 0:
            stopInternal(reason: "Two bytes basic header is not implemented")
            return
        case 1:
            stopInternal(reason: "Three bytes basic header is not implemented")
            return
        default:
            break
        }
        if chunkStreams[chunkStreamId] == nil {
            chunkStreams[chunkStreamId] = RtmpServerChunkStream(client: self, streamId: chunkStreamId)
        }
        chunkStream = chunkStreams[chunkStreamId]
        chunkStream.isMessageType0 = format == 0
        switch format {
        case 0:
            receiveMessageHeaderType0()
        case 1:
            receiveMessageHeaderType1()
        case 2:
            receiveMessageHeaderType2()
        case 3:
            receiveMessageHeaderType3()
        default:
            fatalError("Invalid chunk format")
        }
    }

    private func handleDataHandshakeDoneMessageHeaderType0(data: Data) {
        guard data.count == 11 else {
            stopInternal(reason: "Wrong length \(data.count) in message header type 0 header")
            return
        }
        chunkStream.messageTimestamp = data.getThreeBytesBe()
        chunkStream.messageLength = Int(data.getThreeBytesBe(offset: 3))
        chunkStream.messageTypeId = data[6]
        chunkStream.messageStreamId = data.getFourBytesLe(offset: 7)
        receiveExtendedTimestampOrData()
    }

    private func handleDataHandshakeDoneMessageHeaderType1(data: Data) {
        guard data.count == 7 else {
            stopInternal(reason: "Wrong length \(data.count) in message header type 1 header")
            return
        }
        chunkStream.messageTimestamp = data.getThreeBytesBe()
        chunkStream.messageLength = Int(data.getThreeBytesBe(offset: 3))
        chunkStream.messageTypeId = data[6]
        receiveExtendedTimestampOrData()
    }

    private func handleDataHandshakeDoneMessageHeaderType2(data: Data) {
        guard data.count == 3 else {
            stopInternal(reason: "Wrong length \(data.count) in message header type 2 header")
            return
        }
        chunkStream.messageTimestamp = data.getThreeBytesBe()
        receiveExtendedTimestampOrData()
    }

    private func handleDataHandshakeDoneData(data: Data) {
        chunkStream.handleData(data: data)
        receiveBasicHeaderFirstByte()
    }

    private func receiveExtendedTimestampOrData() {
        if isExtendedTimestamp(timestamp: chunkStream.messageTimestamp) {
            receiveExtendedTimestamp()
        } else {
            receiveChunkData()
        }
    }

    private func isExtendedTimestamp(timestamp: UInt32) -> Bool {
        chunkStream.extendedTimestampPresentInType3 = timestamp == 0xFFFFFF
        return chunkStream.extendedTimestampPresentInType3
    }

    private func receiveExtendedTimestamp() {
        receiveData(size: 4)
        chunkState = .extendedTimestamp
    }

    private func receiveBasicHeaderFirstByte() {
        receiveData(size: 1)
        chunkState = .basicHeaderFirstByte
    }

    private func receiveMessageHeaderType0() {
        receiveData(size: 11)
        chunkState = .messageHeaderType0
    }

    private func receiveMessageHeaderType1() {
        receiveData(size: 7)
        chunkState = .messageHeaderType1
    }

    private func receiveMessageHeaderType2() {
        receiveData(size: 3)
        chunkState = .messageHeaderType2
    }

    private func receiveMessageHeaderType3() {
        if chunkStream.extendedTimestampPresentInType3 {
            receiveExtendedTimestamp()
        } else {
            receiveChunkData()
        }
    }

    private func receiveChunkData() {
        let size = chunkStream.getChunkDataSize()
        if size > 0 {
            receiveData(size: size)
            chunkState = .data
        } else {
            stopInternal(reason: "Unexpected data")
        }
    }

    func receiveData(size: Int) {
        connection.receive(minimumIncompleteLength: size, maximumLength: size) { data, _, _, error in
            if let data {
                // logger.info("rtmp-server: client: Got data \(data)")
                self.totalBytesReceived += UInt64(data.count)
                self.server?.totalBytesReceived += UInt64(data.count)
                let now = ContinuousClock.now
                if logger.debugEnabled {
                    let elapsed = self.latestReceiveTime.duration(to: now)
                    if elapsed > .milliseconds(500) {
                        logger.debug("rtmp-server: client: \(elapsed.milliseconds) ms since last byte")
                    }
                }
                self.latestReceiveTime = now
                self.handleData(data: data)
                if self.totalBytesReceived - self.totalBytesReceivedAcked > self.windowAcknowledgementSize {
                    self.sendAck()
                    self.totalBytesReceivedAcked = self.totalBytesReceived
                }
            }
            if let error {
                self.stopInternal(reason: "Error \(error)")
            }
        }
    }

    private func sendAck() {
        let message = RTMPAcknowledgementMessage()
        message.sequence = UInt32(totalBytesReceived & 0xFFFF_FFFF)
        sendMessage(chunk: RTMPChunk(
            type: .zero,
            streamId: RTMPChunk.StreamID.control.rawValue,
            message: message
        ))
    }

    func sendMessage(chunk: RTMPChunk) {
        for chunk in chunk.split(chunkSizeToClient) {
            send(data: chunk)
        }
    }

    private func send(data: Data) {
        connection.send(content: data, completion: .contentProcessed { _ in
        })
    }
}
