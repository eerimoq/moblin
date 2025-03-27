// SRTLA is a bonding protocol on top of SRT.
// Designed by rationalsa for the BELABOX projecct.
// https://github.com/BELABOX/srtla

import Foundation
import Network

var srtlaBatchSend = false

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

protocol RemoteConnectionDelegate: AnyObject {
    func remoteConnectionOnSocketConnected(connection: RemoteConnection)
    func remoteConnectionOnReg2(groupId: Data)
    func remoteConnectionOnRegistered()
    func remoteConnectionPacketHandler(packet: Data)
    func remoteConnectionOnSrtAck(sn: UInt32)
    func remoteConnectionOnSrtNak(sn: UInt32)
    func remoteConnectionOnSrtlaAck(sn: UInt32)
}

class RemoteConnection {
    var type: NWInterface.InterfaceType?
    private var connection: NWConnection? {
        didSet {
            oldValue?.stateUpdateHandler = nil
            oldValue?.forceCancel()
        }
    }

    private var connectTimer = SimpleTimer(queue: srtlaClientQueue)
    private var keepaliveTimer = SimpleTimer(queue: srtlaClientQueue)
    private var latestReceivedTime = ContinuousClock.now
    private var packetsInFlight: Set<UInt32> = []
    private var windowSize: Int = 0
    private var numberOfNullPacketsSent: UInt64 = 0
    private var numberOfNonNullPacketsSent: UInt64 = 0
    private var hasGroupId: Bool = false
    private var groupId: Data!
    private var priority: Float
    private var state = State.idle {
        didSet {
            logger.debug("srtla: \(typeString): State \(oldValue) -> \(state)")
        }
    }

    private var keepAliveSendBaseTime = ContinuousClock.now
    var rtt: Int = 0
    let interface: NWInterface?
    private var dataPacketsToSend: [Data] = []
    private var totalDataSentByteCount: UInt64 = 0

    private var nullPacket: Data = {
        var packet = Data(count: MpegTsPacket.size)
        packet
            .setUInt32Be(value: (UInt32(MpegTsPacket.syncByte) << 24) | (UInt32(0x1FFF) << 8) |
                (UInt32(0x1) << 4))
        return packet
    }()

    private(set) var host: NWEndpoint.Host?
    private(set) var port: NWEndpoint.Port?
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
            return relayName ?? "Any"
        }
    }

    let relayId: UUID?
    private let relayName: String?

    weak var delegate: RemoteConnectionDelegate?
    private var networkInterfaces: SrtlaNetworkInterfaces

    init(
        type: NWInterface.InterfaceType?,
        mpegtsPacketsPerPacket: Int,
        interface: NWInterface?,
        networkInterfaces: SrtlaNetworkInterfaces,
        priority: Float,
        relayId: UUID? = nil,
        relayName: String? = nil
    ) {
        self.type = type
        self.mpegtsPacketsPerPacket = mpegtsPacketsPerPacket
        self.interface = interface
        self.networkInterfaces = networkInterfaces
        self.priority = priority
        self.relayId = relayId
        self.relayName = relayName
    }

    deinit {
        logger.debug("srtla: \(typeString): deinit remote connection")
    }

    func setPriority(priority: Float) {
        self.priority = priority
    }

    func start(host: NWEndpoint.Host, port: NWEndpoint.Port) {
        self.host = host
        self.port = port
        startInternal()
    }

    private func startInternal() {
        guard state == .idle, let host, let port else {
            return
        }
        logger.info("srtla: \(typeString): Start with destination \(host):\(port)")
        let params = NWParameters(dtls: .none)
        params.prohibitExpensivePaths = false
        params.requiredInterface = interface
        connection = NWConnection(host: host, port: port, using: params)
        connection!.stateUpdateHandler = handleStateUpdate(to:)
        connection!.start(queue: srtlaClientQueue)
        receivePacket()
        state = .socketConnecting
    }

    func stop(reason: String) {
        let sent = sizeFormatter.string(fromByteCount: Int64(totalDataSentByteCount))
        logger.debug("srtla: \(typeString): Stop with reason: \(reason) (\(sent) sent)")
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
        keepaliveTimer.stop()
        connectTimer.stop()
    }

    private func handleStateUpdate(to state: NWConnection.State) {
        logger.debug("srtla: \(typeString): State change to \(state)")
        switch state {
        case .ready:
            cancelAllTimers()
            connectTimer.startSingleShot(timeout: 5) {
                self.reconnect(reason: "Connection timeout")
            }
            latestReceivedTime = .now
            packetsInFlight.removeAll()
            totalDataSentByteCount = 0
            windowSize = windowDefault * windowMultiply
            if type == nil {
                self.state = .registered
                connectTimer.stop()
            } else if self.state == .shouldSendRegisterRequest || hasGroupId {
                sendSrtlaReg2()
            } else {
                self.state = .shouldSendRegisterRequest
            }
            delegate?.remoteConnectionOnSocketConnected(connection: self)
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
                self.handlePacketFromClient(packet: packet)
            }
            if let error {
                logger.warning("srtla: \(self.typeString): Receive \(error)")
                return
            }
            self.receivePacket()
        }
    }

    private func sendPacket(packet: Data) {
        if isSrtDataPacket(packet: packet) {
            packetsInFlight.insert(getSrtSequenceNumber(packet: packet))
            var numberOfMpegTsPackets = (packet.count - 16) / MpegTsPacket.size
            numberOfNonNullPacketsSent += UInt64(numberOfMpegTsPackets)
            if numberOfMpegTsPackets < mpegtsPacketsPerPacket {
                var paddedPacket = packet
                while numberOfMpegTsPackets < mpegtsPacketsPerPacket {
                    paddedPacket.append(nullPacket)
                    numberOfMpegTsPackets += 1
                    numberOfNullPacketsSent += 1
                }
                sendDataPacketInternal(packet: paddedPacket)
                totalDataSentByteCount += UInt64(paddedPacket.count)
            } else {
                sendDataPacketInternal(packet: packet)
                totalDataSentByteCount += UInt64(packet.count)
            }
        } else {
            sendControlPacketInternal(packet: packet)
        }
    }

    private func sendControlPacketInternal(packet: Data) {
        connection?.send(content: packet, completion: .idempotent)
    }

    private func sendDataPacketInternal(packet: Data) {
        if srtlaBatchSend {
            dataPacketsToSend.append(packet)
        } else {
            connection?.send(content: packet, completion: .idempotent)
        }
    }

    func sendSrtPacket(packet: Data) {
        sendPacket(packet: packet)
    }

    func flushDataPackets() {
        guard !dataPacketsToSend.isEmpty else {
            return
        }
        connection?.batch {
            for packet in dataPacketsToSend {
                connection?.send(content: packet, completion: .idempotent)
            }
        }
        dataPacketsToSend.removeAll()
    }

    func register(groupId: Data) {
        self.groupId = groupId
        hasGroupId = true
        if state == .shouldSendRegisterRequest {
            sendSrtlaReg2()
        }
    }

    func sendSrtlaReg1() {
        logger.debug("srtla: \(typeString): Sending reg 1 (create group)")
        groupId = Data.random(length: 256)
        var packet = createSrtlaPacket(type: .reg1, length: srtControlTypeSize + groupId.count)
        packet[srtControlTypeSize...] = groupId
        sendPacket(packet: packet)
    }

    private func sendSrtlaReg2() {
        logger.debug("srtla: \(typeString): Sending reg 2 (register connection)")
        var packet = createSrtlaPacket(type: .reg2, length: srtControlTypeSize + groupId.count)
        packet[srtControlTypeSize...] = groupId
        sendPacket(packet: packet)
        state = .waitForRegisterResponse
    }

    private func sendSrtlaKeepalive() {
        var packet = createSrtlaPacket(type: .keepalive, length: srtControlTypeSize + 8)
        packet.setInt64Be(value: getKeepAliveTime(), offset: srtControlTypeSize)
        sendPacket(packet: packet)
    }

    private func getKeepAliveTime() -> Int64 {
        return keepAliveSendBaseTime.duration(to: .now).milliseconds
    }

    private func handleSrtAck(packet: Data) {
        guard packet.count >= 20 else {
            return
        }
        delegate?.remoteConnectionOnSrtAck(sn: getSrtSequenceNumber(packet: packet[16 ..< 20]))
    }

    func handleSrtAckSn(sn ackSn: UInt32) {
        packetsInFlight = packetsInFlight.filter { sn in !isSrtSnAcked(sn: sn, ackSn: ackSn) }
    }

    private func handleSrtNak(packet: Data) {
        processSrtNak(packet: packet) { sn in
            self.delegate?.remoteConnectionOnSrtNak(sn: sn)
        }
    }

    func handleSrtNakSn(sn: UInt32) {
        if packetsInFlight.remove(sn) == nil {
            return
        }
        windowSize = max(windowSize - windowDecrement, windowMinimum * windowMultiply)
    }

    private func handleSrtlaKeepalive(packet: Data) {
        guard packet.count >= 10 else {
            return
        }
        let sendTime = packet.getInt64Be(offset: srtControlTypeSize)
        rtt = Int((getKeepAliveTime() - sendTime).clamped(to: 0 ... 10000))
    }

    private func handleSrtlaAck(packet: Data) {
        guard (packet.count % 4) == 0 else {
            return
        }
        for offset in stride(from: 4, to: packet.count, by: 4) {
            delegate?.remoteConnectionOnSrtlaAck(sn: packet.getUInt32Be(offset: offset))
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
        logger.debug("srtla: \(typeString): Got reg 2 (group created)")
        guard packet.count == 258 else {
            logger.warning("srtla: \(typeString): Wrong reg 2 packet length \(packet.count)")
            return
        }
        guard groupId.count == 256 else {
            return
        }
        let groupIdRange = 0 ..< groupId.count / 2
        guard packet.advanced(by: srtControlTypeSize)[groupIdRange] == groupId[groupIdRange] else {
            logger.warning("srtla: \(typeString): Wrong group id in reg 2")
            return
        }
        delegate?.remoteConnectionOnReg2(groupId: packet.advanced(by: srtControlTypeSize))
    }

    private func handleSrtlaReg3() {
        logger.debug("srtla: \(typeString): Got reg 3 (connection registered)")
        guard state == .waitForRegisterResponse else {
            return
        }
        state = .registered
        delegate?.remoteConnectionOnRegistered()
        connectTimer.stop()
        keepaliveTimer.startPeriodic(interval: 1) {
            let now = ContinuousClock.now
            self.sendSrtlaKeepalive()
            if self.latestReceivedTime < now - .seconds(5) {
                self.reconnect(reason: "No packet received in 5 seconds")
            }
        }
    }

    private func handleSrtlaRegErr() {
        logger.debug("srtla: \(typeString): Register error")
    }

    private func handleSrtlaRegNgp() {
        logger.debug("srtla: \(typeString): Register no group")
    }

    private func handleSrtlaRegNak() {
        logger.debug("srtla: \(typeString): Register nak")
    }

    private func handleSrtlaControlPacket(type: SrtlaPacketType, packet: Data) {
        switch type {
        case .keepalive:
            handleSrtlaKeepalive(packet: packet)
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
        let type = getSrtControlPacketType(packet: packet)
        if let type = SrtlaPacketType(rawValue: type) {
            handleSrtlaControlPacket(type: type, packet: packet)
        } else {
            if let type = SrtPacketType(rawValue: type) {
                handleSrtControlPacket(type: type, packet: packet)
            }
            delegate?.remoteConnectionPacketHandler(packet: packet)
        }
    }

    private func handleDataPacket(packet: Data) {
        delegate?.remoteConnectionPacketHandler(packet: packet)
    }

    private func handlePacketFromClient(packet: Data) {
        guard packet.count >= srtControlTypeSize else {
            logger.error("srtla: \(typeString): Packet too short (\(packet.count) bytes.")
            return
        }
        latestReceivedTime = .now
        if isSrtDataPacket(packet: packet) {
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
