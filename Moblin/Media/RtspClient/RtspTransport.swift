import Foundation
import Network

private let rtspEndOfHeaders = Data([0xD, 0xA, 0xD, 0xA])

protocol RtspTransportDelegate: AnyObject {
    func rtspTransportConnected()
    func rtspTransportDisconnected()
    func rtspTransportReceivedRtspMessage(header: Data, content: Data?)
    func rtspTransportReceivedRtpPacket(_ packet: Data)
    func rtspTransportReceivedRtcpPacket(_ packet: Data)
}

class RtspTransport {
    weak var delegate: (any RtspTransportDelegate)?

    func start(host _: String, port _: Int) {}

    func stop() {}

    func sendRtsp(_: Data) {}

    func sendRtcp(_: Data) {}

    func setupTransportHeader() -> String {
        ""
    }

    func handleSetupTransportResponse(_: String) throws {}
}

class RtspTransportRtpRtspTcp: RtspTransport, @unchecked Sendable {
    private let channelStart = "$".first!.asciiValue!
    private var connection: NWConnection?
    private var rtpChannel: UInt8?
    private var rtcpChannel: UInt8?
    private var header = Data()

    override func start(host: String, port: Int) {
        let connection = NWConnection(
            to: .hostPort(host: .init(host), port: .init(integer: port)),
            using: .init(tls: nil)
        )
        self.connection = connection
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.delegate?.rtspTransportConnected()
            default:
                break
            }
        }
        connection.start(queue: rtspClientQueue)
        receiveMessage()
    }

    override func stop() {
        connection?.cancel()
        connection = nil
    }

    override func sendRtsp(_ data: Data) {
        connection?.send(content: data, completion: .idempotent)
    }

    override func sendRtcp(_ data: Data) {
        guard let rtcpChannel else {
            return
        }
        guard let size = UInt16(exactly: data.count) else {
            return
        }
        let writer = ByteWriter()
        writer.writeUInt8(channelStart)
        writer.writeUInt8(rtcpChannel)
        writer.writeUInt16(size)
        writer.writeBytes(data)
        connection?.send(content: writer.data, completion: .idempotent)
    }

    override func setupTransportHeader() -> String {
        "RTP/AVP/TCP;unicast;interleaved=0-1"
    }

    override func handleSetupTransportResponse(_ value: String) throws {
        guard let match = value.firstMatch(of: /interleaved=(\d+)-(\d+)/) else {
            throw "Invalid interleaving in \(value)."
        }
        rtpChannel = UInt8(match.output.1)
        rtcpChannel = UInt8(match.output.2)
    }

    private func receiveMessage() {
        receive(size: 1) { [weak self] data in
            guard let self else {
                return
            }
            if data[0] == channelStart {
                receiveChannelHeader()
            } else {
                header.removeAll(keepingCapacity: true)
                header += data
                receiveRtspHeaderRemaining()
            }
        }
    }

    private func receiveChannelHeader() {
        receive(size: 3) { [weak self] data in
            guard let self else {
                return
            }
            let channel = data[0]
            let size = data.withUnsafeBytes { pointer in
                pointer.readUInt16(offset: 1)
            }
            receiveChannelData(channel: channel, size: Int(size))
        }
    }

    private func receiveChannelData(channel: UInt8, size: Int) {
        receive(size: size) { [weak self] data in
            guard let self else {
                return
            }
            if channel == rtpChannel {
                delegate?.rtspTransportReceivedRtpPacket(data)
            } else if channel == rtcpChannel {
                delegate?.rtspTransportReceivedRtcpPacket(data)
            }
            receiveMessage()
        }
    }

    private func receiveRtspHeaderRemaining() {
        receive(size: 1) { [weak self] data in
            guard let self else {
                return
            }
            header += data
            if header.suffix(4) == rtspEndOfHeaders {
                let contentLength = parseContentLength(from: header)
                if contentLength > 0 {
                    receiveRtspContent(header: header, size: contentLength)
                } else {
                    delegate?.rtspTransportReceivedRtspMessage(header: header, content: nil)
                    receiveMessage()
                }
            } else {
                receiveRtspHeaderRemaining()
            }
        }
    }

    private func receiveRtspContent(header: Data, size: Int) {
        receive(size: size) { [weak self] data in
            guard let self else {
                return
            }
            delegate?.rtspTransportReceivedRtspMessage(header: header, content: data)
            receiveMessage()
        }
    }

    private func receive(size: Int, onComplete: @escaping @Sendable (Data) throws -> Void) {
        connection?.receive(minimumIncompleteLength: size, maximumLength: size) { data, _, _, _ in
            guard let data else {
                return
            }
            do {
                try onComplete(data)
            } catch {
                logger.debug("rtsp-client: TCP transport error: \(error)")
            }
        }
    }
}

class RtspTransportRtpUdp: RtspTransport, @unchecked Sendable {
    private var host: String = ""
    private var port: Int = 554
    private var rtspConnection: NWConnection?
    private var rtpListener: NWListener?
    private var rtcpListener: NWListener?
    private var rtcpSendConnection: NWConnection?
    private var header = Data()
    private var localRtpPort: NWEndpoint.Port?
    private var localRtcpPort: NWEndpoint.Port?
    private var remoteRtcpPort: NWEndpoint.Port?

    override func start(host: String, port: Int) {
        self.host = host
        self.port = port
        setupUdpListeners()
    }

    override func stop() {
        rtspConnection?.cancel()
        rtspConnection = nil
        rtpListener?.cancel()
        rtpListener = nil
        rtcpListener?.cancel()
        rtcpListener = nil
        rtcpSendConnection?.cancel()
        rtcpSendConnection = nil
        localRtpPort = nil
        localRtcpPort = nil
    }

    override func sendRtsp(_ data: Data) {
        rtspConnection?.send(content: data, completion: .idempotent)
    }

    override func sendRtcp(_ data: Data) {
        if rtcpSendConnection == nil, let remoteRtcpPort {
            rtcpSendConnection = NWConnection(
                to: .hostPort(host: NWEndpoint.Host(host), port: remoteRtcpPort),
                using: .udp
            )
            rtcpSendConnection?.start(queue: rtspClientQueue)
        }
        rtcpSendConnection?.send(content: data, completion: .idempotent)
    }

    override func setupTransportHeader() -> String {
        guard let rtpPort = localRtpPort, let rtcpPort = localRtcpPort else {
            logger.info("rtsp-client: UDP listeners not ready when building transport header")
            return "RTP/AVP;unicast;client_port=0-1"
        }
        return "RTP/AVP;unicast;client_port=\(rtpPort.rawValue)-\(rtcpPort.rawValue)"
    }

    override func handleSetupTransportResponse(_ value: String) throws {
        guard let match = value.firstMatch(of: /server_port=(\d+)-(\d+)/) else {
            throw "Missing server_port in UDP transport response: \(value)"
        }
        guard let rtcpPortValue = UInt16(match.output.2),
              let nwPort = NWEndpoint.Port(rawValue: rtcpPortValue)
        else {
            throw "Invalid RTCP server port in: \(value)"
        }
        remoteRtcpPort = nwPort
    }

    private func setupUdpListeners() {
        do {
            rtpListener = try NWListener(using: .udp)
            rtcpListener = try NWListener(using: .udp)
        } catch {
            logger.debug("rtsp-client: Failed to create UDP listeners: \(error)")
            return
        }
        rtpListener?.stateUpdateHandler = { [weak self] state in
            guard let self else {
                return
            }
            switch state {
            case .ready:
                localRtpPort = rtpListener?.port
                connectRtspIfReady()
            default:
                break
            }
        }
        rtcpListener?.stateUpdateHandler = { [weak self] state in
            guard let self else {
                return
            }
            switch state {
            case .ready:
                localRtcpPort = rtcpListener?.port
                connectRtspIfReady()
            default:
                break
            }
        }
        rtpListener?.newConnectionHandler = { [weak self] connection in
            connection.start(queue: rtspClientQueue)
            self?.receiveRtpDatagram(connection: connection)
        }
        rtcpListener?.newConnectionHandler = { [weak self] connection in
            connection.start(queue: rtspClientQueue)
            self?.receiveRtcpDatagram(connection: connection)
        }
        rtpListener?.start(queue: rtspClientQueue)
        rtcpListener?.start(queue: rtspClientQueue)
    }

    private func connectRtspIfReady() {
        if localRtpPort != nil, localRtcpPort != nil {
            connectRtsp()
        }
    }

    private func connectRtsp() {
        rtspConnection = NWConnection(
            to: .hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integer: port)),
            using: .init(tls: nil)
        )
        rtspConnection?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.delegate?.rtspTransportConnected()
            default:
                break
            }
        }
        rtspConnection?.start(queue: rtspClientQueue)
        receiveRtspMessage()
    }

    private func receiveRtpDatagram(connection: NWConnection) {
        connection.receiveMessage { [weak self] data, _, _, _ in
            guard let self else {
                return
            }
            guard let data else {
                logger.debug("rtsp-client: RTP datagram receive ended")
                return
            }
            delegate?.rtspTransportReceivedRtpPacket(data)
            receiveRtpDatagram(connection: connection)
        }
    }

    private func receiveRtcpDatagram(connection: NWConnection) {
        connection.receiveMessage { [weak self] data, _, _, _ in
            guard let self else {
                return
            }
            guard let data else {
                logger.debug("rtsp-client: RTCP datagram receive ended")
                return
            }
            delegate?.rtspTransportReceivedRtcpPacket(data)
            receiveRtcpDatagram(connection: connection)
        }
    }

    private func receiveRtspMessage() {
        receiveRtsp(size: 1) { [weak self] data in
            guard let self else {
                return
            }
            header.removeAll(keepingCapacity: true)
            header += data
            receiveRtspHeaderRemaining()
        }
    }

    private func receiveRtspHeaderRemaining() {
        receiveRtsp(size: 1) { [weak self] data in
            guard let self else {
                return
            }
            header += data
            if header.suffix(4) == rtspEndOfHeaders {
                let contentLength = parseContentLength(from: header)
                if contentLength > 0 {
                    receiveRtspContent(header: header, size: contentLength)
                } else {
                    delegate?.rtspTransportReceivedRtspMessage(header: header, content: nil)
                    receiveRtspMessage()
                }
            } else {
                receiveRtspHeaderRemaining()
            }
        }
    }

    private func receiveRtspContent(header: Data, size: Int) {
        receiveRtsp(size: size) { [weak self] data in
            guard let self else {
                return
            }
            delegate?.rtspTransportReceivedRtspMessage(header: header, content: data)
            receiveRtspMessage()
        }
    }

    private func receiveRtsp(size: Int, onComplete: @escaping @Sendable (Data) throws -> Void) {
        rtspConnection?
            .receive(minimumIncompleteLength: size, maximumLength: size) { data, _, _, _ in
                guard let data else {
                    return
                }
                do {
                    try onComplete(data)
                } catch {
                    logger.debug("rtsp-client: UDP transport error: \(error)")
                }
            }
    }
}

private func parseContentLength(from header: Data) -> Int {
    guard let header = String(bytes: header, encoding: .utf8) else {
        return 0
    }
    for line in header.split(separator: "\r\n") {
        let lower = line.lowercased()
        if lower.starts(with: "content-length:") {
            let parts = lower.split(separator: ":", maxSplits: 1)
            if parts.count == 2,
               let length = Int(parts[1].trimmingCharacters(in: .whitespaces))
            {
                return length
            }
        }
    }
    return 0
}
