import Foundation

protocol SrtlaDelegate: AnyObject {
    func srtlaReady(port: UInt16)
    func srtlaError(message: String)
}

private enum State {
    case idle
    case waitForRemoteSocketConnected
    case waitForGroupId
    case waitForRegistered
    case waitForLocalSocketListening
    case running
}

let srtlaDispatchQueue = DispatchQueue(label: "com.eerimoq.srtla")

class Srtla {
    private var remoteConnections: [RemoteConnection] = []
    private var localListener: LocalListener?
    private weak var delegate: (any SrtlaDelegate)?
    private let passThrough: Bool
    private var connectTimer: DispatchSourceTimer?
    private var state = State.idle {
        didSet {
            logger.info("srtla: State \(oldValue) -> \(state)")
        }
    }

    private var totalByteCount: Int64 = 0

    init(delegate: SrtlaDelegate, passThrough: Bool, mpegtsPacketsPerPacket: Int) {
        self.delegate = delegate
        self.passThrough = passThrough
        logger.info("srtla: SRT instead of SRTLA: \(passThrough)")
        if passThrough {
            remoteConnections.append(RemoteConnection(
                type: nil,
                mpegtsPacketsPerPacket: mpegtsPacketsPerPacket
            ))
        } else {
            remoteConnections.append(RemoteConnection(
                type: .cellular,
                mpegtsPacketsPerPacket: mpegtsPacketsPerPacket
            ))
            remoteConnections.append(RemoteConnection(
                type: .wifi,
                mpegtsPacketsPerPacket: mpegtsPacketsPerPacket
            ))
            remoteConnections.append(RemoteConnection(
                type: .wiredEthernet,
                mpegtsPacketsPerPacket: mpegtsPacketsPerPacket
            ))
        }
    }

    deinit {
        logger.info("srtla: srtla deinit")
    }

    func start(uri: String, timeout: Double) {
        srtlaDispatchQueue.async {
            self.totalByteCount = 0
            guard
                let url = URL(string: uri),
                let host = url.host,
                let port = url.port
            else {
                logger.error("srtla: Malformed URL")
                return
            }
            for connection in self.remoteConnections {
                self.startRemote(connection: connection, host: host, port: port)
            }
            self.connectTimer = DispatchSource.makeTimerSource(queue: srtlaDispatchQueue)
            logger.info("srtla: Setting connect timer to \(timeout) seconds")
            self.connectTimer!.schedule(deadline: .now() + timeout)
            self.connectTimer!.setEventHandler {
                logger.info("srtla: Connect timer expired after \(timeout) seconds")
                self.onDisconnected(message: "connect timer expired")
            }
            self.connectTimer!.activate()
            self.state = .waitForRemoteSocketConnected
        }
    }

    func stop() {
        srtlaDispatchQueue.async {
            for connection in self.remoteConnections {
                self.stopRemote(connection: connection)
            }
            self.remoteConnections = []
            self.stopListener()
            self.cancelConnectTimer()
            self.state = .idle
        }
    }

    func connectionStatistics() -> String? {
        struct ByteCount {
            var name: String
            var value: UInt64
        }
        var byteCounts: [ByteCount] = []
        var totalByteCount: UInt64 = 0
        srtlaDispatchQueue.sync {
            for connection in remoteConnections {
                guard let byteCount = connection.getDataSentDelta() else {
                    continue
                }
                byteCounts.append(ByteCount(
                    name: connection.typeString,
                    value: byteCount
                ))
                totalByteCount += byteCount
            }
        }
        if byteCounts.isEmpty {
            return nil
        }
        if totalByteCount == 0 {
            totalByteCount = 1
        }
        var percentges = byteCounts.map { byteCount in
            ByteCount(name: byteCount.name, value: 100 * byteCount.value / totalByteCount)
        }
        percentges[percentges.count - 1].value = 100 - percentges
            .prefix(upTo: percentges.count - 1)
            .reduce(0) { total, percentage in
                total + percentage.value
            }
        return percentges.map { percentage in
            "\(percentage.value)% \(percentage.name)"
        }.joined(separator: ", ")
    }

    func logStatistics() {
        srtlaDispatchQueue.async {
            for connection in self.remoteConnections {
                connection.logStatistics()
            }
        }
    }

    func getTotalByteCount() -> Int64 {
        srtlaDispatchQueue.sync {
            totalByteCount
        }
    }

    private func startRemote(connection: RemoteConnection, host: String, port: Int) {
        connection.onSocketConnected = {
            self.handleRemoteConnected(connection: connection)
        }
        connection.onReg2 = handleGroupId(groupId:)
        connection.onRegistered = {
            self.handleRemoteRegistered(connection: connection)
        }
        connection.packetHandler = handleRemotePacket(packet:)
        connection.onSrtAck = handleSrtAck(sn:)
        connection.onSrtNak = handleSrtNak(sn:)
        connection.onSrtlaAck = handleSrtlaAck(sn:)
        connection.start(host: host, port: UInt16(port))
    }

    private func stopRemote(connection: RemoteConnection) {
        connection.stop(reason: "Stopping stream")
        connection.onSocketConnected = nil
        connection.onReg2 = nil
        connection.onRegistered = nil
        connection.packetHandler = nil
        connection.onSrtAck = nil
        connection.onSrtNak = nil
        connection.onSrtlaAck = nil
    }

    private func startListener() {
        guard localListener == nil else {
            return
        }
        localListener = LocalListener()
        localListener!.packetHandler = handleLocalPacket(packet:)
        localListener!.onReady = handleLocalReady(port:)
        localListener!.onError = handleLocalError
        localListener!.start()
        state = .waitForLocalSocketListening
    }

    private func stopListener() {
        localListener?.stop()
        localListener?.packetHandler = nil
        localListener?.onReady = nil
        localListener?.onError = nil
        localListener = nil
    }

    private func handleLocalReady(port: UInt16) {
        guard state == .waitForLocalSocketListening else {
            return
        }
        state = .running
        delegate?.srtlaReady(port: port)
        cancelConnectTimer()
    }

    private func cancelConnectTimer() {
        connectTimer?.cancel()
        connectTimer = nil
    }

    private func handleLocalError(message: String) {
        onDisconnected(message: message)
    }

    private func onDisconnected(message: String) {
        stop()
        delegate?.srtlaError(message: message)
        state = .idle
    }

    private func handleLocalPacket(packet: Data) {
        guard let connection = selectRemoteConnection() else {
            logger.warning("srtla: local: No remote connection found")
            onDisconnected(message: "no remote connection found")
            return
        }
        connection.sendSrtPacket(packet: packet)
        totalByteCount += Int64(packet.count)
    }

    private func handleRemoteConnected(connection: RemoteConnection) {
        guard state == .waitForRemoteSocketConnected else {
            return
        }
        if passThrough {
            startListener()
        } else {
            connection.sendSrtlaReg1()
            state = .waitForGroupId
        }
    }

    private func handleRemoteRegistered(connection _: RemoteConnection) {
        guard state == .waitForRegistered else {
            return
        }
        startListener()
    }

    private func handleRemotePacket(packet: Data) {
        localListener?.sendPacket(packet: packet)
        totalByteCount += Int64(packet.count)
    }

    private func handleSrtAck(sn: UInt32) {
        for connection in remoteConnections {
            connection.handleSrtAckSn(sn: sn)
        }
    }

    private func handleSrtNak(sn: UInt32) {
        for connection in remoteConnections {
            connection.handleSrtNakSn(sn: sn)
        }
    }

    private func handleSrtlaAck(sn: UInt32) {
        for connection in remoteConnections {
            connection.handleSrtlaAckSn(sn: sn)
        }
    }

    private func handleGroupId(groupId: Data) {
        guard state == .waitForGroupId else {
            return
        }
        for connection in remoteConnections {
            connection.register(groupId: groupId)
        }
        state = .waitForRegistered
    }

    private func selectRemoteConnection() -> RemoteConnection? {
        var selectedConnection: RemoteConnection?
        var selectedScore = -1
        for connection in remoteConnections {
            let score = connection.score()
            if score > selectedScore {
                selectedConnection = connection
                selectedScore = score
            }
        }
        return selectedConnection
    }
}
