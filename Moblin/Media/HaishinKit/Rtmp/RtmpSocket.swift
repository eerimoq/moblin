import Foundation
import Network

enum RtmpSocketReadyState {
    case uninitialized
    case versionSent
    case ackSent
    case handshakeDone
    case closed
}

enum RtmpHandshake {
    static let sigSize = 1536
    static let protocolVersion: UInt8 = 3
    private static let timestamp: TimeInterval = 0

    static func createC0C1Packet() -> Data {
        let writer = ByteWriter()
        writer.writeUInt8(RtmpHandshake.protocolVersion)
        writer.writeInt32(Int32(timestamp))
        writer.writeBytes(Data([0x00, 0x00, 0x00, 0x00]))
        for _ in 0 ..< RtmpHandshake.sigSize - 8 {
            writer.writeUInt8(UInt8.random(in: 0 ... UInt8.max))
        }
        return writer.data
    }

    static func createC2Packet(_ s0s1packet: Data) -> Data {
        let writer = ByteWriter()
        writer.writeBytes(s0s1packet.subdata(in: 1 ..< 5))
        writer.writeUInt32(UInt32(truncatingIfNeeded: Int64(Date().timeIntervalSince1970 - timestamp)))
        writer.writeBytes(s0s1packet.subdata(in: 9 ..< RtmpHandshake.sigSize + 1))
        return writer.data
    }
}

protocol RtmpSocketDelegate: AnyObject {
    func socketHandshakeDone(_ socket: RtmpSocket)
    func socketClosed(_ socket: RtmpSocket)
    func socketDisconnected(_ socket: RtmpSocket, code: RtmpStatusCode)
    func socketDataReceived(_ socket: RtmpSocket, data: Data) -> Data
    func socketUpdateStats(_ socket: RtmpSocket, totalBytesSent: Int64)
}

final class RtmpSocket: @unchecked Sendable {
    var maximumChunkSizeToServer = RtmpChunk.defaultSize
    private(set) var readyState: RtmpSocketReadyState = .uninitialized
    private var inputBuffer = Data()
    weak var delegate: (any RtmpSocketDelegate)?
    private var totalBytesSending: Int64 = 0
    private var totalBytesSent: Int64 = 0
    private let name: String
    private var connection: NWConnection?
    private let queue: DispatchQueue

    init(name: String, queue: DispatchQueue) {
        self.name = name
        self.queue = queue
    }

    func connect(host: String, port: Int, tlsOptions: NWProtocolTLS.Options?) {
        setReadyState(state: .uninitialized)
        maximumChunkSizeToServer = RtmpChunk.defaultSize
        totalBytesSending = 0
        totalBytesSent = 0
        inputBuffer.removeAll(keepingCapacity: false)
        connection = NWConnection(
            to: .hostPort(host: .init(host), port: .init(integer: port)),
            using: .init(tls: tlsOptions)
        )
        connection!.viabilityUpdateHandler = viabilityDidChange
        connection!.stateUpdateHandler = stateDidChange
        connection!.start(queue: queue)
        receive(on: connection!)
    }

    func close(isDisconnected: Bool) {
        guard readyState != .closed else {
            return
        }
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
            delegate?.socketDisconnected(self, code: wasHandshakeDone ? .connectClosed : .connectFailed)
        }
    }

    func write(chunk: RtmpChunk) -> Int {
        for data in chunk.split(maximumSize: maximumChunkSizeToServer) {
            write(data: data)
        }
        return chunk.message.length
    }

    private func setReadyState(state: RtmpSocketReadyState) {
        guard readyState != state else {
            return
        }
        logger.info("rtmp: \(name): Setting socket state \(readyState) -> \(state)")
        readyState = state
        switch state {
        case .handshakeDone:
            delegate?.socketHandshakeDone(self)
        case .closed:
            delegate?.socketClosed(self)
        default:
            break
        }
    }

    private func write(data: Data) {
        let size = Int64(data.count)
        totalBytesSending += size
        connection?.send(content: data, completion: .contentProcessed { [weak self] error in
            guard let self else {
                return
            }
            if error != nil {
                close(isDisconnected: true)
                return
            }
            totalBytesSent += size
        })
        delegate?.socketUpdateStats(self, totalBytesSent: totalBytesSending)
        if hasTooMuchDataBuffered() {
            logger.info("rtmp: \(name): Too much data buffered. Disconnecting.")
            queue.async {
                self.close(isDisconnected: true)
            }
        }
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
        case let .waiting(error):
            logger.info("rtmp: \(name): Connection waiting: \(error)")
            close(isDisconnected: true)
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
        connection
            .receive(minimumIncompleteLength: 0,
                     maximumLength: 255)
            { [weak self] data, _, isComplete, error in
                guard let self else {
                    return
                }
                if let data, !data.isEmpty {
                    inputBuffer.append(data)
                    processInput()
                }
                if let error {
                    logger.info("rtmp: \(name): Receive failed: \(error)")
                    close(isDisconnected: true)
                } else if isComplete {
                    logger.info("rtmp: \(name): Connection closed by server")
                    close(isDisconnected: true)
                } else {
                    receive(on: connection)
                }
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
        inputBuffer = delegate.socketDataReceived(self, data: inputBuffer)
    }
}
