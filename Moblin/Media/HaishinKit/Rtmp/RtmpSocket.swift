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
}

final class RtmpSocket {
    var maximumChunkSizeFromServer = RtmpChunk.defaultSize
    var maximumChunkSizeToServer = RtmpChunk.defaultSize
    private var readyState: RtmpSocketReadyState = .uninitialized
    private var inputBuffer = Data()
    weak var delegate: RtmpSocketDelegate?
    private var totalBytesSending: Int64 = 0
    private var totalBytesSent: Int64 = 0
    private let name: String
    private var connection: NWConnection?

    init(name: String) {
        self.name = name
    }

    func connect(host: String, port: Int, tlsOptions: NWProtocolTLS.Options?) {
        setReadyState(state: .uninitialized)
        maximumChunkSizeToServer = RtmpChunk.defaultSize
        maximumChunkSizeFromServer = RtmpChunk.defaultSize
        totalBytesSending = 0
        totalBytesSent = 0
        inputBuffer.removeAll(keepingCapacity: false)
        connection = NWConnection(
            to: .hostPort(host: .init(host), port: .init(integer: port)),
            using: .init(tls: tlsOptions)
        )
        connection!.viabilityUpdateHandler = viabilityDidChange
        connection!.stateUpdateHandler = stateDidChange
        connection!.start(queue: processorControlQueue)
        receive(on: connection!)
    }

    func close(isDisconnected: Bool) {
        connection?.viabilityUpdateHandler = nil
        connection?.stateUpdateHandler = nil
        connection?.cancel()
        connection = nil
        setReadyState(state: .closed)
        if isDisconnected {
            let data: AsObject
            if readyState == .handshakeDone {
                data = RtmpConnectionCode.connectClosed.eventData()
            } else {
                data = RtmpConnectionCode.connectFailed.eventData()
            }
            delegate?.socketPost(data: data)
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
        delegate?.socketReadyStateChanged(readyState: readyState)
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
            delegate?.socketUpdateStats(totalBytesSent: totalBytesSent)
        })
        if hasTooMuchDataBuffered() {
            logger.info("rtmp: \(name): Too much data buffered. Disconnecting.")
            processorControlQueue.async {
                self.close(isDisconnected: true)
            }
        }
    }

    private func hasTooMuchDataBuffered() -> Bool {
        return totalBytesSending - totalBytesSent > 100_000_000
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
            self.inputBuffer.append(data)
            self.processInput()
            self.receive(on: connection)
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
