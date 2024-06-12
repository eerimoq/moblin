import Foundation
import Network

private enum State {
    case idle
    case socketConnecting
    case shouldSendRegisterRequest
    case waitForRegisterResponse
    case registered
}

private let windowDefault = 20
private let windowMinimum = 1
private let windowMaximum = 60
private let windowStableMinimum = 10
private let windowStableMaximum = 20
private let windowMultiply = 1000
private let windowDecrement = 100
private let windowIncrement = 30

class RemoteConnection {
    var type: NWInterface.InterfaceType?
    private var connection: NWConnection? {
        didSet {
            oldValue?.stateUpdateHandler = nil
            oldValue?.forceCancel()
        }
    }

    private var connectTimer: DispatchSourceTimer?
    private var keepaliveTimer: DispatchSourceTimer?
    private var latestReceivedTime = ContinuousClock.now
    private var latestSentTime = ContinuousClock.now
    private var packetsInFlight: Set<UInt32> = []
    private var windowSize: Int = 0
    private var numberOfNullPacketsSent: UInt64 = 0
    private var numberOfNonNullPacketsSent: UInt64 = 0
    private var hasGroupId: Bool = false
    private var groupId: Data!
    private var priority: Float
    private var state = State.idle {
        didSet {
            logger.info("srtla: \(typeString): State \(oldValue) -> \(state)")
        }
    }

    let interface: NWInterface?

    private var totalDataSentByteCount: UInt64 = 0

    private var nullPacket: Data = {
        var packet = Data(count: 188)
        packet
            .setUInt32Be(value: (UInt32(0x47) << 24) | (UInt32(0x1FFF) << 8) |
                (UInt32(0x1) << 4))
        return packet
    }()

    private var host: String!
    private var port: UInt16!
    private let mpegtsPacketsPerPacket: Int
    var typeString: String {
        switch type {
        case .wifi:
            return "WiFi"
        case .wiredEthernet:
            return networkInterfaces.names[interface?.name ?? ""] ?? interface?.name ?? "Ethernet"
        case .cellular:
            return "Cellular"
        default:
            return "Any"
        }
    }

    var onSocketConnected: (() -> Void)?
    var onReg2: ((_ groupId: Data) -> Void)?
    var onRegistered: (() -> Void)?
    var packetHandler: ((_ packet: Data) -> Void)?
    var onSrtAck: ((_ sn: UInt32) -> Void)?
    var onSrtNak: ((_ sn: UInt32) -> Void)?
    var onSrtlaAck: ((_ sn: UInt32) -> Void)?
    private var networkInterfaces: SrtlaNetworkInterfaces

    init(
        type: NWInterface.InterfaceType?,
        mpegtsPacketsPerPacket: Int,
        interface: NWInterface?,
        networkInterfaces: SrtlaNetworkInterfaces,
        priority: Float
    ) {
        self.type = type
        self.mpegtsPacketsPerPacket = mpegtsPacketsPerPacket
        self.interface = interface
        self.networkInterfaces = networkInterfaces
        self.priority = priority
    }

    deinit {
        logger.info("srtla: \(typeString): deinit remote connection")
    }

    func setPriority(priority: Float) {
        self.priority = priority
    }

    func start(host: String, port: UInt16) {
        self.host = host
        self.port = port
        startInternal()
    }

    private func startInternal() {
        logger.info("srtla: \(typeString): Start")
        guard state == .idle else {
            return
        }
        let params = NWParameters(dtls: .none)
        if let type {
            params.requiredInterfaceType = type
        }
        params.prohibitExpensivePaths = false
        params.requiredInterface = interface
        connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(integerLiteral: port),
            using: params
        )
        connection!.stateUpdateHandler = handleStateUpdate(to:)
        connection!.start(queue: srtlaDispatchQueue)
        receivePacket()
        state = .socketConnecting
    }

    func stop(reason: String) {
        let sent = sizeFormatter.string(fromByteCount: Int64(totalDataSentByteCount))
        logger
            .info(
                "srtla: \(typeString): Stop with reason: \(reason) (\(sent) sent)"
            )
        connection?.cancel()
        connection = nil
        cancelAllTimers()
        state = .idle
    }

    func score() -> Int {
        guard state == .registered else {
            return -1
        }

        if type == nil {
            return 1
        } else if priority == 0 {
            return -1
        } else {
            let score = windowSize / (packetsInFlight.count + 1)
            if windowSize > windowStableMaximum * windowMultiply {
                return Int(Float(score) * priority)
            } else if windowSize > windowStableMinimum * windowMultiply {
                var factor = Float(windowSize - windowStableMinimum * windowMultiply)
                factor /= Float((windowStableMaximum - windowStableMinimum) * windowMultiply)
                let scaledPriority = 1 + (priority - 1) * factor
                return Int(Float(score) * scaledPriority)
            } else {
                return score
            }
        }
    }

    func isEnabled() -> Bool {
        return priority > 0
    }

    private func cancelAllTimers() {
        keepaliveTimer?.cancel()
        keepaliveTimer = nil
        connectTimer?.cancel()
        connectTimer = nil
    }

    private func handleStateUpdate(to state: NWConnection.State) {
        logger.info("srtla: \(typeString): State change to \(state)")
        switch state {
        case .ready:
            cancelAllTimers()
            connectTimer = DispatchSource.makeTimerSource(queue: srtlaDispatchQueue)
            connectTimer!.schedule(deadline: .now() + 5)
            connectTimer!.setEventHandler {
                self.reconnect(reason: "Connection timeout")
            }
            connectTimer!.activate()
            latestReceivedTime = .now
            latestSentTime = .now
            packetsInFlight.removeAll()
            totalDataSentByteCount = 0
            windowSize = windowDefault * windowMultiply
            if type == nil {
                self.state = .registered
                connectTimer?.cancel()
                connectTimer = nil
            } else if self.state == .shouldSendRegisterRequest || hasGroupId {
                sendSrtlaReg2()
            } else {
                self.state = .shouldSendRegisterRequest
            }
            onSocketConnected?()
            onSocketConnected = nil
        case .failed:
            reconnect(reason: "Connection failed")
        default:
            break
        }
    }

    private func reconnect(reason: String) {
        stop(reason: reason)
        startInternal()
    }

    private func receivePacket() {
        connection?.receiveMessage { packet, _, _, error in
            if let packet, !packet.isEmpty {
                self.handlePacket(packet: packet)
            }
            if let error {
                logger.warning("srtla: \(self.typeString): Receive \(error)")
                return
            }
            self.receivePacket()
        }
    }

    private func sendPacket(packet: Data) {
        if isDataPacket(packet: packet) {
            var numberOfMpegTsPackets = (packet.count - 16) / 188
            numberOfNonNullPacketsSent += UInt64(numberOfMpegTsPackets)
            if numberOfMpegTsPackets < mpegtsPacketsPerPacket {
                var paddedPacket = packet
                while numberOfMpegTsPackets < mpegtsPacketsPerPacket {
                    paddedPacket.append(nullPacket)
                    numberOfMpegTsPackets += 1
                    numberOfNullPacketsSent += 1
                }
                sendPacketInternal(packet: paddedPacket)
                totalDataSentByteCount += UInt64(paddedPacket.count)
            } else {
                sendPacketInternal(packet: packet)
                totalDataSentByteCount += UInt64(packet.count)
            }
        } else {
            sendPacketInternal(packet: packet)
        }
    }

    private func sendPacketInternal(packet: Data) {
        latestSentTime = .now
        connection?.send(content: packet, completion: .contentProcessed { _ in })
    }

    func sendSrtPacket(packet: Data) {
        if isDataPacket(packet: packet) {
            packetsInFlight.insert(getSequenceNumber(packet: packet))
        }
        sendPacket(packet: packet)
    }

    func register(groupId: Data) {
        self.groupId = groupId
        hasGroupId = true
        if state == .shouldSendRegisterRequest {
            sendSrtlaReg2()
        }
    }

    func sendSrtlaReg1() {
        logger.info("srtla: \(typeString): Sending reg 1 (create group)")
        groupId = Data.random(length: 256)
        var packet = Data(count: 2 + groupId.count)
        packet.setUInt16Be(value: SrtlaPacketType.reg1.rawValue | srtlaPacketTypeBit)
        packet[2...] = groupId
        sendPacket(packet: packet)
    }

    private func sendSrtlaReg2() {
        logger.info("srtla: \(typeString): Sending reg 2 (register connection)")
        var packet = Data(count: 2 + groupId.count)
        packet.setUInt16Be(value: SrtlaPacketType.reg2.rawValue | srtlaPacketTypeBit)
        packet[2...] = groupId
        sendPacket(packet: packet)
        state = .waitForRegisterResponse
    }

    private func sendSrtlaKeepalive() {
        var packet = Data(count: 2)
        packet.setUInt16Be(value: SrtlaPacketType.keepalive.rawValue | srtlaPacketTypeBit)
        sendPacket(packet: packet)
    }

    private func handleSrtAck(packet: Data) {
        guard packet.count >= 20 else {
            return
        }
        onSrtAck?(getSequenceNumber(packet: packet[16 ..< 20]))
    }

    func handleSrtAckSn(sn ackSn: UInt32) {
        packetsInFlight = packetsInFlight
            .filter { sn in !isSnAcked(sn: sn, ackSn: ackSn) }
    }

    private func handleSrtNak(packet: Data) {
        var offset = 16
        while offset <= packet.count - 4 {
            let nakSn = packet.getUInt32Be(offset: offset)
            offset += 4
            if isSnRange(sn: nakSn) {
                guard offset <= packet.count - 4 else {
                    logger
                        .error(
                            """
                            srtla: \(typeString): Missing second sequence number in \
                            range nak at offset \(offset) with packet length \(packet
                                .count)
                            """
                        )
                    return
                }
                let upToNakSn = packet.getUInt32Be(offset: offset)
                for sn in stride(from: nakSn & 0x7FFF_FFFF, through: upToNakSn, by: 1) {
                    onSrtNak?(sn)
                }
                offset += 4
            } else {
                onSrtNak?(nakSn)
            }
        }
    }

    func handleSrtNakSn(sn: UInt32) {
        if packetsInFlight.remove(sn) == nil {
            return
        }
        windowSize = max(windowSize - windowDecrement, windowMinimum * windowMultiply)
    }

    private func handleSrtlaKeepalive() {}

    private func handleSrtlaAck(packet: Data) {
        guard (packet.count % 4) == 0 else {
            return
        }
        for offset in stride(from: 4, to: packet.count, by: 4) {
            onSrtlaAck?(packet.getUInt32Be(offset: offset))
        }
    }

    func handleSrtlaAckSn(sn: UInt32) {
        if packetsInFlight.remove(sn) != nil {
            if packetsInFlight.count * windowMultiply > windowSize {
                windowSize += windowIncrement - 1
            }
        }
        windowSize = min(windowSize + 1, windowMaximum * windowMultiply)
    }

    private func handleSrtlaReg2(packet: Data) {
        logger.info("srtla: \(typeString): Got reg 2 (group created)")
        guard packet.count == 258 else {
            logger.warning("srtla: \(typeString): Wrong reg 2 packet length \(packet.count)")
            return
        }
        guard groupId.count == 256 else {
            return
        }
        guard packet[2 ..< groupId.count / 2 + 2] == groupId[0 ..< groupId.count / 2]
        else {
            logger.warning("srtla: \(typeString): Wrong group id in reg 2")
            return
        }
        onReg2?(packet[2...])
    }

    private func handleSrtlaReg3() {
        logger.info("srtla: \(typeString): Got reg 3 (connection registered)")
        guard state == .waitForRegisterResponse else {
            return
        }
        state = .registered
        onRegistered?()
        connectTimer?.cancel()
        connectTimer = nil
        keepaliveTimer = DispatchSource.makeTimerSource(queue: srtlaDispatchQueue)
        keepaliveTimer!.schedule(deadline: .now() + 1, repeating: 1)
        keepaliveTimer!.setEventHandler {
            let now = ContinuousClock.now
            if self.latestSentTime < now - .seconds(0.5) {
                self.sendSrtlaKeepalive()
            }
            if self.latestReceivedTime < now - .seconds(5) {
                self.reconnect(reason: "No packet received in 5 seconds")
            }
        }
        keepaliveTimer!.activate()
    }

    private func handleSrtlaRegErr() {
        logger.info("srtla: \(typeString): Register error")
    }

    private func handleSrtlaRegNgp() {
        logger.info("srtla: \(typeString): Register no group")
    }

    private func handleSrtlaRegNak() {
        logger.info("srtla: \(typeString): Register nak")
    }

    private func handleSrtlaControlPacket(type: SrtlaPacketType, packet: Data) {
        switch type {
        case .keepalive:
            handleSrtlaKeepalive()
        case .ack:
            handleSrtlaAck(packet: packet)
        case .reg1:
            logger.error("srtla: \(typeString): Received register 1 packet")
        case .reg2:
            handleSrtlaReg2(packet: packet)
        case .reg3:
            handleSrtlaReg3()
        case .regErr:
            handleSrtlaRegErr()
        case .regNgp:
            handleSrtlaRegNgp()
        case .regNak:
            handleSrtlaRegNak()
        }
    }

    private func handleSrtControlPacket(type: SrtPacketType, packet: Data) {
        guard packet.count >= 16 else {
            return
        }
        switch type {
        case .ack:
            handleSrtAck(packet: packet)
        case .nak:
            handleSrtNak(packet: packet)
        default:
            break
        }
    }

    private func handleControlPacket(packet: Data) {
        let type = getControlPacketType(packet: packet)
        if let type = SrtlaPacketType(rawValue: type) {
            handleSrtlaControlPacket(type: type, packet: packet)
        } else {
            if let type = SrtPacketType(rawValue: type) {
                handleSrtControlPacket(type: type, packet: packet)
            }
            packetHandler?(packet)
        }
    }

    private func handleDataPacket(packet: Data) {
        packetHandler?(packet)
    }

    private func handlePacket(packet: Data) {
        guard packet.count >= 2 else {
            logger.error("srtla: \(typeString): Packet too short (\(packet.count) bytes.")
            return
        }
        latestReceivedTime = .now
        if isDataPacket(packet: packet) {
            handleDataPacket(packet: packet)
        } else {
            handleControlPacket(packet: packet)
        }
    }

    func logStatistics() {
        guard state == .registered else {
            return
        }
        var overhead = 0
        let total = numberOfNullPacketsSent + numberOfNonNullPacketsSent
        if total > 0 {
            overhead = Int(100 * Double(numberOfNullPacketsSent) / Double(total))
        }
        numberOfNullPacketsSent = 0
        numberOfNonNullPacketsSent = 0
        if type == nil {
            logger.debug("srtla: \(typeString): Overhead: \(overhead) %")
        } else {
            logger
                .debug(
                    """
                    srtla: \(typeString): Score: \(score()), In flight: \
                    \(packetsInFlight.count), Window size: \(windowSize), \
                    Priority: \(priority), Overhead: \(overhead) %
                    """
                )
        }
    }

    func getDataSentDelta() -> UInt64? {
        defer {
            totalDataSentByteCount = 0
        }
        guard state == .registered else {
            return nil
        }
        return totalDataSentByteCount
    }
}
