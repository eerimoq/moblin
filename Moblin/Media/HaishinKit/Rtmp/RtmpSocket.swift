import Foundation
import Network

enum RtmpSocketReadyState {
    case uninitialized
    case versionSent
    case ackSent
    case handshakeDone
    case closed
}

protocol RtmpSocketDelegate: AnyObject {
    func socketDataReceived(data: Data) -> Data
    func socketReadyStateChanged(readyState: RtmpSocketReadyState)
    func socketUpdateStats(totalBytesSent: Int64)
    func socketPost(data: AsObject)
    func socketGetCurrentBitrate() -> UInt32
}

final class RtmpSocket: @unchecked Sendable {
    var maximumChunkSizeFromServer = RtmpChunk.defaultSize
    var maximumChunkSizeToServer = RtmpChunk.defaultSize
    private var readyState: RtmpSocketReadyState = .uninitialized
    private var inputBuffer = Data()
    weak var delegate: (any RtmpSocketDelegate)?
    private(set) var totalBytesSending: Int64 = 0
    private(set) var totalBytesSent: Int64 = 0
    private let name: String
    private var connection: NWConnection?
    private let queue: DispatchQueue
    private let sendQueue = RtmpSendQueue()
    private var isFlushing = Atomic<Bool>(false)

    init(name: String, queue: DispatchQueue) {
        self.name = name
        self.queue = queue
    }

    func connect(host: String, port: Int, tlsOptions: NWProtocolTLS.Options?) {
        setReadyState(state: .uninitialized)
        maximumChunkSizeToServer = RtmpChunk.defaultSize
        maximumChunkSizeFromServer = RtmpChunk.defaultSize
        totalBytesSending = 0
        totalBytesSent = 0
        sendQueue.clear()
        isFlushing.mutate { $0 = false }
        inputBuffer.removeAll(keepingCapacity: false)
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.noDelay = true
        let parameters = NWParameters(tls: tlsOptions, tcp: tcpOptions)
        connection = NWConnection(
            to: .hostPort(host: .init(host), port: .init(integer: port)),
            using: parameters
        )
        connection!.viabilityUpdateHandler = viabilityDidChange
        connection!.stateUpdateHandler = stateDidChange
        connection!.start(queue: queue)
        receive(on: connection!)
    }

    func close(isDisconnected: Bool) {
        if let connection {
            connection.viabilityUpdateHandler = nil
            connection.stateUpdateHandler = nil
            // Workaround for closeStream RTMP command not being sent.
            queue.asyncAfter(deadline: .now() + 1) {
                connection.cancel()
            }
        }
        let wasHandshakeDone = readyState == .handshakeDone
        setReadyState(state: .closed)
        if isDisconnected {
            let data: AsObject = if wasHandshakeDone {
                RtmpConnectionCode.connectClosed.eventData()
            } else {
                RtmpConnectionCode.connectFailed.eventData()
            }
            delegate?.socketPost(data: data)
        }
    }

    private let serializer = RtmpChunkSerializer()

    private var isDropModeActive = false

    /// Heuristic estimate of outbound send pressure.
    ///
    /// Computed as:
    /// bytesSubmittedToNWConnection - bytesCompletedByContentProcessed
    ///
    /// This is NOT the actual TCP congestion window,
    /// kernel socket send buffer occupancy,
    /// or TCP retransmission queue.
    ///
    /// It is an application-level estimate useful for
    /// congestion detection and adaptive bitrate decisions.
    func estimatedSendPressure() -> Double {
        let expectedBufferedSeconds = 0.6
        let minimumBacklogBytes = 300_000.0 // Evita sensibilidade extrema em bitrates baixos
        let recentSendRateBytesPerSecond = Double(delegate?.socketGetCurrentBitrate() ?? 500_000) / 8.0
        let maxBacklog = max(minimumBacklogBytes, recentSendRateBytesPerSecond * expectedBufferedSeconds)
        let bufferedBytes = Double(max(0, totalBytesSending - totalBytesSent))
        return min(1.0, bufferedBytes / maxBacklog)
    }

    func write(chunk: RtmpChunk) -> Int {
        let pressure = estimatedSendPressure()

        if isDropModeActive {
            if pressure < 0.65 {
                isDropModeActive = false
            }
        } else {
            if pressure > 0.85 {
                isDropModeActive = true
                sendQueue.dropInterframes() // Limpa o atrasado na transição
                // requestKeyframe() can be called here if needed
            }
        }

        let priority = priorityFor(chunk: chunk)

        // Bloqueia a entrada de novos P-Frames enquanto a congestão persistir
        if isDropModeActive, priority == .videoInterframe {
            return chunk.message!.length
        }

        let serializedChunks = serializer.serialize(
            chunk: chunk,
            maximumChunkSize: maximumChunkSizeToServer
        )
        for data in serializedChunks {
            sendQueue.enqueue(data, priority: priority)
        }
        flush()
        return chunk.message!.length
    }

    private func priorityFor(chunk: RtmpChunk) -> RtmpChunkPriority {
        if chunk.type == .zero || chunk.chunkStreamId == RtmpChunk.ChunkStreamId.control.rawValue {
            return .control
        }
        if chunk.chunkStreamId == FlvTagType.audio.streamId {
            return .audio
        }
        if chunk.chunkStreamId == FlvTagType.video.streamId {
            if let payload = chunk.message?.encoded, !payload.isEmpty {
                let firstByte = payload[0]
                let isExtended = (firstByte & 0b1000_0000) != 0
                let frameType = isExtended ? ((firstByte & 0b0111_0000) >> 4) : (firstByte >> 4)
                if frameType == FlvFrameType.key.rawValue {
                    return .videoKeyframe
                }
                return .videoInterframe
            }
            return .videoKeyframe
        }
        return .metadata
    }

    private func setReadyState(state: RtmpSocketReadyState) {
        guard readyState != state else {
            return
        }
        logger.info("rtmp: \(name): Setting socket state \(readyState) -> \(state)")
        readyState = state
        delegate?.socketReadyStateChanged(readyState: readyState)
    }

    private func flush() {
        var shouldFlush = false
        isFlushing.mutate {
            if !$0 {
                $0 = true
                shouldFlush = true
            }
        }
        guard shouldFlush else { return }

        queue.async { [weak self] in
            self?.performFlush()
        }
    }

    private func performFlush() {
        guard let data = sendQueue.dequeue() else {
            isFlushing.mutate { $0 = false }
            return
        }

        let size = Int64(data.count)
        totalBytesSending += size

        connection?.send(content: data, completion: .contentProcessed { [weak self] error in
            guard let self else { return }
            if error != nil {
                close(isDisconnected: true)
                return
            }

            totalBytesSent += size
            delegate?.socketUpdateStats(totalBytesSent: totalBytesSending)

            if hasTooMuchDataBuffered() {
                logger.info("rtmp: \(name): Too much data buffered. Disconnecting.")
                queue.async {
                    self.close(isDisconnected: true)
                }
                return
            }

            queue.async {
                self.performFlush()
            }
        })
    }

    private func write(data: Data) {
        sendQueue.enqueue(data, priority: .control)
        flush()
    }

    private func hasTooMuchDataBuffered() -> Bool {
        totalBytesSending - totalBytesSent > 100_000_000
    }

    private func viabilityDidChange(to viability: Bool) {
        logger.info("rtmp: \(name): Connection viability changed to \(viability)")
        if !viability {
            close(isDisconnected: true)
        }
    }

    private func stateDidChange(to state: NWConnection.State) {
        switch state {
        case .ready:
            logger.info("rtmp: \(name): Connection is ready.")
            write(data: RtmpHandshake.createC0C1Packet())
            setReadyState(state: .versionSent)
        case let .failed(error):
            logger.info("rtmp: \(name): Connection failed: \(error)")
            close(isDisconnected: true)
        case .cancelled:
            logger.info("rtmp: \(name): Connection cancelled.")
            close(isDisconnected: true)
        default:
            break
        }
    }

    private func receive(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 0, maximumLength: 255) { [weak self] data, _, _, _ in
            guard let self, let data else {
                return
            }
            inputBuffer.append(data)
            processInput()
            receive(on: connection)
        }
    }

    private func processInput() {
        switch readyState {
        case .versionSent:
            processInputVersionSent()
        case .ackSent:
            processInputAckSent()
        case .handshakeDone:
            processInputHandshakeDone()
        default:
            break
        }
    }

    private func processInputVersionSent() {
        guard inputBuffer.count >= RtmpHandshake.sigSize + 1 else {
            return
        }
        write(data: RtmpHandshake.createC2Packet(inputBuffer))
        inputBuffer.removeSubrange(0 ... RtmpHandshake.sigSize)
        setReadyState(state: .ackSent)
        processInput()
    }

    private func processInputAckSent() {
        guard inputBuffer.count >= RtmpHandshake.sigSize else {
            return
        }
        inputBuffer.removeAll()
        setReadyState(state: .handshakeDone)
    }

    private func processInputHandshakeDone() {
        guard !inputBuffer.isEmpty, let delegate else {
            return
        }
        inputBuffer = delegate.socketDataReceived(data: inputBuffer)
    }
}
