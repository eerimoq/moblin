import Foundation
import Network

enum RTMPSocketReadyState: UInt8 {
    case uninitialized = 0
    case versionSent = 1
    case ackSent = 2
    case handshakeDone = 3
    case closing = 4
    case closed = 5
}

protocol RTMPSocketDelegate: AnyObject {
    func socketDataReceived(_ socket: RTMPSocket, data: Data)
    func socketReadyStateChanged(_ socket: RTMPSocket, readyState: RTMPSocketReadyState)
    func socketUpdateStats(_ socket: RTMPSocket, totalBytesOut: Int64)
    func socketDispatch(_ socket: RTMPSocket, event: Event)
}

final class RTMPSocket {
    var maximumChunkSizeFromServer = RTMPChunk.defaultSize
    var maximumChunkSizeToServer = RTMPChunk.defaultSize
    private let timeout = 10
    private var readyState: RTMPSocketReadyState = .uninitialized

    var secure = false {
        didSet {
            if secure {
                tlsOptions = .init()
            } else {
                tlsOptions = nil
            }
        }
    }

    var inputBuffer = Data()
    weak var delegate: (any RTMPSocketDelegate)?

    private(set) var totalBytesIn: Atomic<Int64> = .init(0)
    private(set) var totalBytesOut: Atomic<Int64> = .init(0)
    private(set) var connected = false {
        didSet {
            if connected {
                write(data: handshake.c0c1packet)
                setReadyState(state: .versionSent)
            } else {
                setReadyState(state: .closed)
                for event in events {
                    delegate?.socketDispatch(self, event: event)
                }
                events.removeAll()
            }
        }
    }

    private func setReadyState(state: RTMPSocketReadyState) {
        logger.info("rtmp: Setting socket state \(readyState) -> \(state)")
        readyState = state
        delegate?.socketReadyStateChanged(self, readyState: readyState)
    }

    private var events: [Event] = []
    private var handshake = RTMPHandshake()
    private var connection: NWConnection? {
        didSet {
            oldValue?.viabilityUpdateHandler = nil
            oldValue?.stateUpdateHandler = nil
            oldValue?.forceCancel()
            if connection == nil {
                connected = false
            }
        }
    }

    private var tlsOptions: NWProtocolTLS.Options?
    private lazy var networkQueue = DispatchQueue(
        label: "com.haishinkit.HaishinKit.RTMPSocket.network",
        qos: .userInitiated
    )
    private var timeoutHandler: DispatchWorkItem?

    func connect(withName: String, port: Int) {
        handshake.clear()
        setReadyState(state: .uninitialized)
        maximumChunkSizeToServer = RTMPChunk.defaultSize
        maximumChunkSizeFromServer = RTMPChunk.defaultSize
        totalBytesIn.mutate { $0 = 0 }
        totalBytesOut.mutate { $0 = 0 }
        inputBuffer.removeAll(keepingCapacity: false)
        connection = NWConnection(
            to: NWEndpoint
                .hostPort(host: .init(withName),
                          port: .init(integerLiteral: NWEndpoint.Port.IntegerLiteralType(port))),
            using: .init(tls: tlsOptions, tcp: NWProtocolTCP.Options())
        )
        connection?.viabilityUpdateHandler = viabilityDidChange(to:)
        connection?.stateUpdateHandler = stateDidChange(to:)
        connection?.start(queue: networkQueue)
        if let connection {
            receive(on: connection)
        }
        if timeout > 0 {
            let newTimeoutHandler = DispatchWorkItem { [weak self] in
                guard let self = self, self.timeoutHandler?.isCancelled == false else {
                    return
                }
                self.didTimeout()
            }
            timeoutHandler = newTimeoutHandler
            DispatchQueue.global(qos: .userInteractive).asyncAfter(
                deadline: .now() + .seconds(timeout),
                execute: newTimeoutHandler
            )
        }
    }

    func close(isDisconnected: Bool) {
        guard let connection else {
            return
        }
        if isDisconnected {
            let data: ASObject = (readyState == .handshakeDone) ?
                RTMPConnection.Code.connectClosed.data("") : RTMPConnection.Code.connectFailed.data("")
            events.append(Event(type: .rtmpStatus, data: data))
        }
        setReadyState(state: .closing)
        if !isDisconnected, connection.state == .ready {
            connection.send(
                content: nil,
                contentContext: .finalMessage,
                isComplete: true,
                completion: .contentProcessed { _ in
                    self.connection = nil
                }
            )
        } else {
            self.connection = nil
        }
        timeoutHandler?.cancel()
    }

    @discardableResult
    func write(chunk: RTMPChunk) -> Int {
        for data in chunk.split(maximumChunkSizeToServer) {
            write(data: data)
        }
        return chunk.message!.length
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
            self.totalBytesOut.mutate { $0 += Int64(data.count) }
            self.delegate?.socketUpdateStats(self, totalBytesOut: self.totalBytesOut.value)
        })
    }

    private func viabilityDidChange(to viability: Bool) {
        logger.info("rtmp: Connection viability changed to \(viability)")
        if !viability {
            close(isDisconnected: true)
        }
    }

    private func stateDidChange(to state: NWConnection.State) {
        switch state {
        case .ready:
            logger.info("rtmp: Connection is ready.")
            timeoutHandler?.cancel()
            connected = true
        case let .waiting(error):
            logger.info("rtmp: Connection waiting: \(error)")
        case .setup:
            logger.debug("rtmp: Connection is setting up.")
        case .preparing:
            logger.debug("rtmp: Connection is preparing.")
        case let .failed(error):
            logger.info("rtmp: Connection failed: \(error)")
            close(isDisconnected: true)
        case .cancelled:
            logger.info("rtmp: Connection cancelled.")
            close(isDisconnected: true)
        @unknown default:
            logger.error("rtmp: Unknown connection state.")
        }
    }

    private func receive(on connection: NWConnection) {
        connection
            .receive(minimumIncompleteLength: 0, maximumLength: 255) { [weak self] data, _, _, _ in
                guard let self, let data, self.connected else {
                    return
                }
                self.inputBuffer.append(data)
                self.totalBytesIn.mutate { $0 += Int64(data.count) }
                self.processInput()
                self.receive(on: connection)
            }
    }

    private func processInput() {
        switch readyState {
        case .versionSent:
            if inputBuffer.count < RTMPHandshake.sigSize + 1 {
                break
            }
            write(data: handshake.c2packet(inputBuffer))
            inputBuffer.removeSubrange(0 ... RTMPHandshake.sigSize)
            setReadyState(state: .ackSent)
            if RTMPHandshake.sigSize <= inputBuffer.count {
                processInput()
            }
        case .ackSent:
            if inputBuffer.count < RTMPHandshake.sigSize {
                break
            }
            inputBuffer.removeAll()
            setReadyState(state: .handshakeDone)
        case .handshakeDone, .closing:
            if inputBuffer.isEmpty {
                break
            }
            let bytes = inputBuffer
            inputBuffer.removeAll()
            delegate?.socketDataReceived(self, data: bytes)
        default:
            break
        }
    }

    private func didTimeout() {
        logger.info("rtmp: Connect timeout")
        close(isDisconnected: true)
    }
}
