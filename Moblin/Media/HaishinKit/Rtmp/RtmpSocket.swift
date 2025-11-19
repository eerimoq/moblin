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
    func socketDataReceived(_ socket: RtmpSocket, data: Data) -> Data
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
    private var totalBytesSent: Int64 = 0
    private let connectTimer = SimpleTimer(queue: processorControlQueue)
    private let name: String
    private(set) var connected = false
    private var connection: NWConnection?

    init(name: String) {
        self.name = name
    }

    func connect(host: String, port: Int, tlsOptions: NWProtocolTLS.Options?) {
        setReadyState(state: .uninitialized)
        maximumChunkSizeToServer = RtmpChunk.defaultSize
        maximumChunkSizeFromServer = RtmpChunk.defaultSize
        totalBytesSent = 0
        inputBuffer.removeAll(keepingCapacity: false)
        connection = NWConnection(
            to: .hostPort(host: .init(host), port: .init(integer: port)),
            using: .init(tls: tlsOptions)
        )
        if let connection {
            connection.viabilityUpdateHandler = viabilityDidChange
            connection.stateUpdateHandler = stateDidChange
            connection.start(queue: processorControlQueue)
            receive(on: connection)
        }
        startConnectTimer()
    }

    func close(isDisconnected: Bool) {
        connection?.viabilityUpdateHandler = nil
        connection?.stateUpdateHandler = nil
        connection?.cancel()
        connection = nil
        setReadyState(state: .closed)
        connected = false
        if isDisconnected {
            let data: AsObject
            if readyState == .handshakeDone {
                data = RtmpConnectionCode.connectClosed.eventData()
            } else {
                data = RtmpConnectionCode.connectFailed.eventData()
            }
            delegate?.socketPost(data: data)
        }
        stopConnectTimer()
    }

    func write(chunk: RtmpChunk) -> Int {
        for data in chunk.split(maximumSize: maximumChunkSizeToServer) {
            write(data: data)
        }
        return chunk.message!.length
    }

    private func startConnectTimer() {
        connectTimer.startSingleShot(timeout: 10) { [weak self] in
            self?.handleConnectTimeout()
        }
    }

    private func stopConnectTimer() {
        connectTimer.stop()
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
        connection?.send(content: data, completion: .contentProcessed { error in
            guard self.connected else {
                return
            }
            if error != nil {
                self.close(isDisconnected: true)
                return
            }
            self.totalBytesSent += Int64(data.count)
            self.delegate?.socketUpdateStats(totalBytesSent: self.totalBytesSent)
        })
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
            stopConnectTimer()
            write(data: RtmpHandshake.createC0C1Packet())
            setReadyState(state: .versionSent)
            connected = true
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
            guard let self, let data, self.connected else {
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
        inputBuffer = delegate.socketDataReceived(self, data: inputBuffer)
    }

    private func handleConnectTimeout() {
        logger.info("rtmp: \(name): Connect timeout")
        close(isDisconnected: true)
    }
}
