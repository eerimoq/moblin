import Foundation
import libsrt
import Network

private let srtlaServerQueue = DispatchQueue(label: "com.eerimoq.srtla-server")
private let srtServerQueue = DispatchQueue(label: "com.eerimoq.srtla-srt-server")

class SrtlaServer {
    private var listener: NWListener!
    private var clients: [Data: SrtlaServerClient] = [:]
    var settings: SettingsSrtlaServer
    private var srtListenerSocket: SRTSOCKET = SRT_INVALID_SOCK

    init(settings: SettingsSrtlaServer) {
        self.settings = settings
    }

    func start() {
        srtlaServerQueue.async {
            self.startSrtListener()
            self.startSrtlaListener()
        }
    }

    func stop() {
        srtlaServerQueue.async {
            self.stopSrtlaListener()
            self.stopSrtListener()
        }
    }

    private func startSrtListener() {
        srt_startup()
        srtServerQueue.async {
            self.srtListenerMain()
        }
    }
    
    private func stopSrtListener() {
        srt_close(srtListenerSocket)
        srtListenerSocket = SRT_INVALID_SOCK
        srt_cleanup()
    }
    
    private func srtListenerMain() {
        srtListenerSocket = srt_create_socket()
        print("xxx", srtListenerSocket)
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout.size(ofValue: addr))
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_addr.s_addr = inet_addr("0.0.0.0")
        addr.sin_port = in_port_t(bigEndian: settings.srtPort)
        let addrSize = MemoryLayout.size(ofValue: addr)
        var res = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                srt_bind(srtListenerSocket, $0, Int32(addrSize))
            }
        }
        guard res != SRT_ERROR else {
            logger.info("srtla-server: SRT bind failed.")
            return
        }
        res = srt_listen(srtListenerSocket, 5)
        guard res != SRT_ERROR else {
            logger.info("srtla-server: SRT listen failed.")
            return
        }
        // srt_listen_callback() // check stream id
        while true {
            logger.info("srtla-server: Waiting for clients to connect.")
            let clientSocket = srt_accept(srtListenerSocket, nil, nil)
            guard clientSocket != SRT_ERROR else {
                logger.info("srtla-server: Accept failed.")
                break
            }
            logger.info("srtla-server: Accepted client socket \(clientSocket). Should read packets from it.")
            srt_close(clientSocket)
        }
    }
    
    private func startSrtlaListener() {
        logger.info("srtla-server: Setup listener")
        guard let srtlaPort = NWEndpoint.Port(rawValue: settings.srtlaPort) else {
            logger.error("srtla-server: Bad listener port \(settings.srtlaPort)")
            return
        }
        let parameters = NWParameters(dtls: .none, udp: .init())
        parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.any), port: srtlaPort)
        parameters.allowLocalEndpointReuse = true
        do {
            listener = try NWListener(using: parameters)
        } catch {
            logger.error("srtla-server: Failed to create listener with error \(error)")
            return
        }
        listener.stateUpdateHandler = handleListenerStateChange(to:)
        listener.newConnectionHandler = handleNewListenerConnection(connection:)
        listener.start(queue: srtlaServerQueue)
    }
    
   private  func stopSrtlaListener() {
            listener?.cancel()
            listener = nil
    }

    private func handleListenerStateChange(to state: NWListener.State) {
        logger.info("srtla-server: State change to \(state)")
        switch state {
        case .ready:
            logger.info("srtla-server: Listening on port \(listener.port!.rawValue)")
        default:
            break
        }
    }

    private func handleNewListenerConnection(connection: NWConnection) {
        logger.info("srtla-server: Client \(connection.endpoint) connected")
        connection.start(queue: srtlaDispatchQueue)
        receivePacket(connection: connection)
    }

    private func receivePacket(connection: NWConnection) {
        connection.receiveMessage { data, _, _, error in
            var clientAsReceiver = false
            if let data, !data.isEmpty {
                clientAsReceiver = self.handlePacket(connection: connection, packet: data)
            }
            if let error {
                logger.info("srtla-server: Error \(error)")
                return
            }
            if !clientAsReceiver {
                self.receivePacket(connection: connection)
            }
        }
    }

    private func handlePacket(connection: NWConnection, packet: Data) -> Bool {
        guard packet.count >= 2 else {
            logger.error("srtla-server: Packet too short (\(packet.count) bytes.")
            return false
        }
        if !isDataPacket(packet: packet) {
            return handleControlPacket(connection: connection, packet: packet)
        }
        return false
    }

    private func handleControlPacket(connection: NWConnection, packet: Data) -> Bool {
        let type = getControlPacketType(packet: packet)
        if let type = SrtlaPacketType(rawValue: type) {
            return handleSrtlaControlPacket(connection: connection, type: type, packet: packet)
        }
        return false
    }

    private func handleSrtlaControlPacket(connection: NWConnection, type: SrtlaPacketType,
                                          packet: Data) -> Bool
    {
        switch type {
        case .reg1:
            handleSrtlaReg1(connection: connection, packet: packet)
        case .reg2:
            return handleSrtlaReg2(connection: connection, packet: packet)
        default:
            logger.info("srtla-server: Discarding srtla control packet \(type)")
        }
        return false
    }

    private func handleSrtlaReg1(connection: NWConnection, packet: Data) {
        logger.info("srtla-server: Got reg 1 (create group)")
        guard packet.count == 258 else {
            logger.warning("srtla-server: Wrong reg 1 packet length \(packet.count)")
            return
        }
        let groupId = packet[2 ..< 2 + 128] + Data.random(length: 128)
        clients[groupId] = .init()
        sendSrtlaReg2(connection: connection, groupId: groupId)
    }

    private func handleSrtlaReg2(connection: NWConnection, packet: Data) -> Bool {
        logger.info("srtla-server: Got reg 2 (register connection)")
        guard packet.count == 258 else {
            logger.warning("srtla-server: Wrong reg 2 packet length \(packet.count)")
            return false
        }
        let groupId = packet[2...]
        guard let client = clients[groupId] else {
            logger.warning("srtla-server: Unknown group id in reg 2 packet")
            return false
        }
        client.addConnection(connection: connection)
        sendSrtlaReg3(connection: connection)
        return true
    }

    private func sendSrtlaReg2(connection: NWConnection, groupId: Data) {
        logger.info("srtla-server: Sending reg 2 (group created)")
        var packet = Data(count: 258)
        packet.setUInt16Be(value: SrtlaPacketType.reg2.rawValue | srtlaPacketTypeBit)
        packet[2...] = groupId
        sendPacket(connection: connection, packet: packet)
    }

    private func sendSrtlaReg3(connection: NWConnection) {
        logger.info("srtla-server: Sending reg 3 (connection registered)")
        var packet = Data(count: 2)
        packet.setUInt16Be(value: SrtlaPacketType.reg3.rawValue | srtlaPacketTypeBit)
        sendPacket(connection: connection, packet: packet)
    }

    private func sendPacket(connection: NWConnection, packet: Data) {
        connection.send(content: packet, completion: .contentProcessed { _ in })
    }
}
