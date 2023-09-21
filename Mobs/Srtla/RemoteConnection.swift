import Foundation
import Network

enum SrtPacketType: UInt16 {
    case ack = 0x0002
    case nak = 0x0003
}

enum SrtlaPacketType: UInt16 {
    case keepAlive = 0x1000
    case ack = 0x1100
    case reg1 = 0x1200
    case reg2 = 0x1201
    case reg3 = 0x1202
    case regErr = 0x1210
    case regNgp = 0x1211
    case regNak = 0x1212
}

let connectionTimeout = 4.0

protocol SrtlaDelegate: AnyObject {
    func srtlaReady(port: UInt16)
    func srtlaError()
    func srtlaPacketSent(byteCount: Int)
    func srtlaPacketReceived(byteCount: Int)
    func srtlaConnectionTypeChanged(type: String)
}

func isDataPacket(packet: Data) -> Bool {
    return (packet[0] & 0x80) == 0
}

func getDataPacketSn(packet: Data) -> UInt32 {
    return packet.getUInt32Be()
}

func getControlPacketType(packet: Data) -> UInt16 {
    return packet.getUInt16Be() & 0x7FFF
}

class RemoteConnection {
    private var queue: DispatchQueue
    private var type: NWInterface.InterfaceType?
    private var connection: NWConnection? {
        didSet {
            oldValue?.viabilityUpdateHandler = nil
            oldValue?.stateUpdateHandler = nil
            oldValue?.forceCancel()
        }
    }

    var typeString: String
    var packetHandler: ((_ packet: Data) -> Void)!

    init(queue: DispatchQueue, type: NWInterface.InterfaceType?) {
        self.queue = queue
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
        connection!.stateUpdateHandler = handleStateChange(to:)
        connection!.start(queue: queue)
        receivePacket()
    }

    func stop() {
        connection?.cancel()
        connection = nil
    }

    func score() -> Int {
        guard let connection, connection.state == .ready else {
            return -1
        }
        switch type {
        case .cellular:
            return 1
        case .wifi:
            return 1
        case .wiredEthernet:
            return 1
        case nil:
            return 1
        default:
            return -1
        }
    }

    private func handleViabilityChange(to viability: Bool) {
        logger
            .info(
                "srtla: \(typeString): Connection viability changed to \(viability)"
            )
    }

    private func handleStateChange(to state: NWConnection.State) {
        logger.info("srtla: \(typeString): Connection state changed to \(state)")
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
            } else {
                // logger.debug("srtla: \(self.typeString): Sent \(packet)")
            }
        })
    }

    private var groupId = Data.random(length: 256)

    // Register a connection group.
    func sendSrtlaReg1() {
        logger.info("srtla: \(typeString): Send register 1")
        var packet = Data(capacity: 2 + groupId.count)
        packet.setUInt16Be(value: SrtlaPacketType.reg1.rawValue | 0x8000)
        packet[2...] = groupId
        sendPacket(packet: packet)
    }

    // Register the connection.
    func sendSrtlaReg2() {
        logger.info("srtla: \(typeString): Send register 2")
        var packet = Data(capacity: 2 + groupId.count)
        packet.setUInt16Be(value: SrtlaPacketType.reg2.rawValue | 0x8000)
        packet[2...] = groupId
        sendPacket(packet: packet)
    }

    func handleSrtAck() {
    }

    func handleSrtNak() {
    }

    func handleSrtlaKeepalive() {
        logger.info("srtla: \(typeString): Keep alive")
    }

    func handleSrtlaAck() {
        logger.info("srtla: \(typeString): Ack")
    }

    // Received as response to reg_1. Contains group id (our id +
    // server id).
    func handleSrtlaReg2() {
        logger.info("srtla: \(typeString): Register 2")
    }

    // Received as response to reg_2. A connection has been
    // established.
    func handleSrtlaReg3() {
        logger.info("srtla: \(typeString): Register 3")
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

    func handleControlPacket(packet: Data) {
        let type = getControlPacketType(packet: packet)
        if let type = SrtPacketType(rawValue: type) {
            switch type {
            case .ack:
                handleSrtAck()
            case .nak:
                handleSrtNak()
            }
            packetHandler(packet)
        } else if let type = SrtlaPacketType(rawValue: type) {
            switch type {
            case .keepAlive:
                handleSrtlaKeepalive()
            case .ack:
                handleSrtlaAck()
            case .reg1:
                logger.error("srtla: \(typeString): Received register 1 packet")
            case .reg2:
                handleSrtlaReg2()
            case .reg3:
                handleSrtlaReg3()
            case .regErr:
                handleSrtlaRegErr()
            case .regNgp:
                handleSrtlaRegNgp()
            case .regNak:
                handleSrtlaRegNak()
            }
        } else {
            packetHandler(packet)
        }
    }

    func handleDataPacket(packet: Data) {
        packetHandler(packet)
    }

    func handlePacket(packet: Data) {
        guard packet.count >= 16 else {
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
