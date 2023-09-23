import Foundation
import Network

enum SrtPacketType: UInt16 {
    case ack = 0x0002
    case nak = 0x0003
}

enum SrtlaPacketType: UInt16 {
    case keepalive = 0x1000
    case ack = 0x1100
    case reg1 = 0x1200
    case reg2 = 0x1201
    case reg3 = 0x1202
    case regErr = 0x1210
    case regNgp = 0x1211
    case regNak = 0x1212
}

let connectionTimeout = 4.0

func isDataPacket(packet: Data) -> Bool {
    return (packet[0] & 0x80) == 0
}

func getDataPacketSn(packet: Data) -> UInt32 {
    return packet.getUInt32Be()
}

func getControlPacketType(packet: Data) -> UInt16 {
    return packet.getUInt16Be() & 0x7FFF
}

private enum State {
    case idle
    case socketConnecting
    case shouldSendRegisterRequest
    case waitForRegisterResponse
    case registered
}

class RemoteConnection {
    private var type: NWInterface.InterfaceType?
    private var connection: NWConnection? {
        didSet {
            oldValue?.viabilityUpdateHandler = nil
            oldValue?.stateUpdateHandler = nil
            oldValue?.forceCancel()
        }
    }

    private var reconnectTimer: Timer?
    private var reconnectTime = firstReconnectTime
    private var keepaliveTimer: Timer?
    private var lastReceivedDate: Date!

    private var hasGroupId: Bool = false
    private var groupId: Data!
    private var state = State.idle {
        didSet {
            logger.info("srtla: \(typeString): State \(oldValue) -> \(state)")
        }
    }

    private var host: String!
    private var port: UInt16!
    var typeString: String
    var onSocketConnected: (() -> Void)?
    var onReg2: ((_ groupId: Data) -> Void)?
    var onRegistered: (() -> Void)?
    var packetHandler: ((_ packet: Data) -> Void)?

    init(type: NWInterface.InterfaceType?) {
        self.type = type
        switch type {
        case .wifi:
            typeString = "WiFi"
        case .wiredEthernet:
            typeString = "Ethernet"
        case .cellular:
            typeString = "Cellular"
        default:
            typeString = "Any"
        }
    }

    func start(host: String, port: UInt16) {
        self.host = host
        self.port = port
        startInternal()
    }

    func startInternal() {
        guard state == .idle else {
            return
        }
        reconnectTime = firstReconnectTime
        let options = NWProtocolUDP.Options()
        let params = NWParameters(dtls: .none, udp: options)
        if let type {
            params.requiredInterfaceType = type
        }
        params.prohibitExpensivePaths = false
        connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(integerLiteral: port),
            using: params
        )
        connection!.viabilityUpdateHandler = handleViabilityChange(to:)
        connection!.start(queue: DispatchQueue.main)
        receivePacket()
        state = .socketConnecting
    }

    func stop() {
        connection?.cancel()
        connection = nil
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        keepaliveTimer?.invalidate()
        keepaliveTimer = nil
        state = .idle
    }

    func score() -> Int {
        guard state == .registered else {
            return -1
        }
        switch type {
        case .cellular:
            return 2
        case .wifi:
            return 1
        case .wiredEthernet:
            return 3
        case nil:
            return 1
        default:
            return -1
        }
    }

    private func handleViabilityChange(to viability: Bool) {
        if viability {
            if state == .shouldSendRegisterRequest || hasGroupId {
                sendSrtlaReg2()
            } else if type == nil {
                state = .registered
            } else {
                state = .shouldSendRegisterRequest
            }
            onSocketConnected?()
            onSocketConnected = nil
        } else {
            stop()
            reconnect()
        }
    }

    func reconnect() {
        reconnectTimer = Timer
            .scheduledTimer(withTimeInterval: reconnectTime, repeats: false) { _ in
                logger.warning("srtla: \(self.typeString): Reconnecting")
                self.startInternal()
                self.reconnectTime = nextReconnectTime(self.reconnectTime)
            }
    }

    private func receivePacket() {
        guard let connection else {
            return
        }
        connection
            .receive(minimumIncompleteLength: 1,
                     maximumLength: 4096)
        { packet, _, _, error in
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

    func sendPacket(packet: Data) {
        guard let connection else {
            logger
                .warning("srtla: \(typeString): Dropping packet. No connection.")
            return
        }
        connection.send(content: packet, completion: .contentProcessed { error in
            if let error {
                logger
                    .error(
                        "srtla: \(self.typeString): Remote send error: \(error)"
                    )
            }
        })
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
        packet.setUInt16Be(value: SrtlaPacketType.reg1.rawValue | 0x8000)
        packet[2...] = groupId
        sendPacket(packet: packet)
        state = .shouldSendRegisterRequest
    }

    func sendSrtlaReg2() {
        logger.info("srtla: \(typeString): Sending reg 2 (register connection)")
        var packet = Data(count: 2 + groupId.count)
        packet.setUInt16Be(value: SrtlaPacketType.reg2.rawValue | 0x8000)
        packet[2...] = groupId
        sendPacket(packet: packet)
        state = .waitForRegisterResponse
    }

    func sendSrtlaKeepalive() {
        var packet = Data(count: 2)
        packet.setUInt16Be(value: SrtlaPacketType.keepalive.rawValue | 0x8000)
        sendPacket(packet: packet)
    }

    func handleSrtAck() {}

    func handleSrtNak() {}

    func handleSrtlaKeepalive() {
        lastReceivedDate = Date()
    }

    func handleSrtlaAck() {
        // logger.info("srtla: \(typeString): Ack")
    }

    func handleSrtlaReg2(packet: Data) {
        logger.info("srtla: \(typeString): Got reg 2 (group created)")
        guard packet.count == 258 else {
            logger.warning("srtla: \(typeString): Wrong reg 2 packet length \(packet.count)")
            return
        }
        guard packet[2 ..< groupId.count / 2 + 2] == groupId[0 ..< groupId.count / 2]
        else {
            logger.warning("srtla: \(typeString): Wrong group id in reg 2")
            return
        }
        onReg2?(packet[2...])
    }

    func handleSrtlaReg3() {
        logger.info("srtla: \(typeString): Got reg 3 (connection registered)")
        guard state == .waitForRegisterResponse else {
            return
        }
        state = .registered
        onRegistered?()
        lastReceivedDate = Date()
        keepaliveTimer = Timer
            .scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                self.sendSrtlaKeepalive()
                if self.lastReceivedDate + 5 < Date() {
                    self.stop()
                    self.reconnect()
                }
            }
    }

    func handleSrtlaRegErr() {
        logger.info("srtla: \(typeString): Register error")
    }

    func handleSrtlaRegNgp() {
        logger.info("srtla: \(typeString): Register no group")
    }

    func handleSrtlaRegNak() {
        logger.info("srtla: \(typeString): Register nak")
    }

    func handleSrtlaControlPacket(type: SrtlaPacketType, packet: Data) {
        switch type {
        case .keepalive:
            handleSrtlaKeepalive()
        case .ack:
            handleSrtlaAck()
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

    func handleSrtControlPacket(type: SrtPacketType, packet _: Data) {
        switch type {
        case .ack:
            handleSrtAck()
        case .nak:
            handleSrtNak()
        }
    }

    func handleControlPacket(packet: Data) {
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

    func handleDataPacket(packet: Data) {
        packetHandler?(packet)
    }

    func handlePacket(packet: Data) {
        guard packet.count >= 2 else {
            logger.error("srtla: \(typeString): Packet too short.")
            return
        }
        if isDataPacket(packet: packet) {
            handleDataPacket(packet: packet)
        } else {
            handleControlPacket(packet: packet)
        }
    }
}
