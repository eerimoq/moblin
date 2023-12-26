import Foundation
import HaishinKit
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
    case data
}

class RtmpServerClient {
    private var connection: NWConnection
    private var state: ClientState {
        didSet {
            logger.info("rtmp-server: client: State change \(oldValue) -> \(state)")
        }
    }

    private var chunkState: ChunkState
    private var chunkSizeToClient = 128
    var chunkSizeFromClient = 128
    private var chunkStreams: [UInt32: RtmpServerChunkStream]
    private var chunkStreamId: UInt32
    private var messageTimestamp: UInt32
    private var messageTypeId: UInt8
    private var messageStreamId: UInt32
    private var messageLength: Int
    private var onDisconnected: ((RtmpServerClient) -> Void)?

    init(connection: NWConnection) {
        self.connection = connection
        state = .uninitialized
        chunkState = .basicHeaderFirstByte
        messageTimestamp = 0
        messageTypeId = 0
        messageStreamId = 0
        messageLength = 0
        chunkStreams = [:]
        chunkStreamId = 0
        connection.stateUpdateHandler = handleStateUpdate(to:)
        connection.start(queue: rtmpServerDispatchQueue)
    }

    func start(onDisconnected: @escaping (RtmpServerClient) -> Void) {
        self.onDisconnected = onDisconnected
        state = .uninitialized
        chunkState = .basicHeaderFirstByte
        receiveData(size: 1 + 1536)
    }

    func stop() {
        for chunkStream in chunkStreams.values {
            chunkStream.stop()
        }
        chunkStreams.removeAll()
        connection.cancel()
        onDisconnected = nil
    }

    private func stopInternal() {
        onDisconnected?(self)
    }

    private func handleStateUpdate(to state: NWConnection.State) {
        logger.info("rtmp-server: client: Socket state change to \(state)")
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
            logger.info(
                """
                rtmp-server: client: Wrong length \(data.count) in \
                uninitialized (expected \(1 + 1536)
                """
            )
            stopInternal()
            return
        }
        let version = data[0]
        // logger.info("rtmp-server: client: Client requested version \(version)")
        guard version == rtmpVersion else {
            logger.info("rtmp-server: client: Only version 3 is supported, not \(version)")
            stopInternal()
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
        case .data:
            handleDataHandshakeDoneData(data: data)
        }
    }

    private func handleDataHandshakeDoneBasicHeaderFirstByte(data: Data) {
        guard data.count == 1 else {
            logger
                .info(
                    "rtmp-server: client: Wrong length \(data.count) in basic header first byte (expected 1)"
                )
            stopInternal()
            return
        }
        let firstByte = data[0]
        let format = firstByte >> 6
        chunkStreamId = UInt32(firstByte & 0x3F)
        // logger.info("rtmp-server: client: First byte fmt \(format) and chunk stream id \(chunkStreamId)")
        switch chunkStreamId {
        case 0:
            logger.info("rtmp-server: client: Two bytes basic header is not implemented")
            stopInternal()
            return
        case 1:
            logger.info("rtmp-server: client: Three bytes basic header is not implemented")
            stopInternal()
            return
        default:
            break
        }
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
            fatalError("Invalid fmt")
        }
    }

    private func handleDataHandshakeDoneMessageHeaderType0(data: Data) {
        guard data.count == 11 else {
            logger.info(
                """
                rtmp-server: client: Wrong length \(data.count) om message \
                header type 0 header (expected 11)
                """
            )
            stopInternal()
            return
        }
        messageTimestamp = data.getThreeBytesBe()
        messageLength = Int(data.getThreeBytesBe(offset: 3))
        messageTypeId = data[6]
        messageStreamId = data.getFourBytesBe(offset: 7)
        if let length = getChunkStream()?.handleType0(
            messageTypeId: messageTypeId,
            messageLength: messageLength
        ), length > 0 {
            receiveChunkData(size: length)
        } else {
            logger.info("rtmp-server: client: Unexpected data. Close connection.")
            stopInternal()
        }
    }

    private func getChunkStream() -> RtmpServerChunkStream? {
        if chunkStreams[chunkStreamId] == nil {
            // logger.info("rtmp-server: client: New chunk stream with id \(chunkStreamId)")
            chunkStreams[chunkStreamId] = RtmpServerChunkStream(client: self, chunkStreamId: chunkStreamId)
        }
        return chunkStreams[chunkStreamId]
    }

    private func handleDataHandshakeDoneMessageHeaderType1(data: Data) {
        guard data.count == 7 else {
            logger.info("""
            rtmp-server: client: Wrong length \(data.count) in message header \
            type 1 header (expected 7)
            """)
            stopInternal()
            return
        }
        messageTimestamp = data.getThreeBytesBe()
        messageLength = Int(data.getThreeBytesBe(offset: 3))
        messageTypeId = data[6]
        if let length = getChunkStream()?.handleType1(
            messageTypeId: messageTypeId,
            messageLength: messageLength
        ), length > 0 {
            receiveChunkData(size: length)
        } else {
            logger.info("rtmp-server: client: Unexpected data. Close connection.")
        }
    }

    private func handleDataHandshakeDoneMessageHeaderType2(data: Data) {
        guard data.count == 3 else {
            logger.info(
                """
                rtmp-server: client: Wrong length \(data.count) in message header \
                type 2 header (expected 3)
                """
            )
            stopInternal()
            return
        }
        messageTimestamp = data.getThreeBytesBe()
        if let length = getChunkStream()?.handleType2(), length > 0 {
            receiveChunkData(size: length)
        } else {
            logger.info("rtmp-server: client: Unexpected data. Close connection.")
            stopInternal()
        }
    }

    private func handleDataHandshakeDoneData(data: Data) {
        getChunkStream()?.handleData(data: data)
        receiveBasicHeaderFirstByte()
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
        if let length = getChunkStream()?.handleType3(), length > 0 {
            receiveChunkData(size: length)
        } else {
            logger.info("rtmp-server: client: Unexpected data. Close connection.")
            stopInternal()
        }
    }

    private func receiveChunkData(size: Int) {
        receiveData(size: size)
        chunkState = .data
    }

    func receiveData(size: Int) {
        connection.receive(minimumIncompleteLength: size, maximumLength: size) { data, _, _, error in
            if let data {
                // logger.info("rtmp-server: client: Got data \(data)")
                self.handleData(data: data)
            }
            if let error {
                logger.info("rtmp-server: client: Error \(error)")
                self.stopInternal()
            }
        }
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
