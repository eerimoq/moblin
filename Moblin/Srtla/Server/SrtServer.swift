import Foundation
import libsrt

class SrtServer {
    var settings: SettingsSrtlaServer
    private var listenerSocket: SRTSOCKET = SRT_INVALID_SOCK
    private var acceptedStreamId = ""

    init(settings: SettingsSrtlaServer) {
        self.settings = settings
    }

    func start() {
        srt_startup()
        DispatchQueue(label: "com.eerimoq.srtla-srt-server").async {
            do {
                try self.main()
            } catch {
                logger.info("srtla-server: \(error)")
            }
        }
    }

    func stop() {
        srt_close(listenerSocket)
        listenerSocket = SRT_INVALID_SOCK
        srt_cleanup()
    }

    private func main() throws {
        try open()
        try bind()
        try listen()
        while true {
            logger.info("srtla-server: Waiting for client to connect.")
            let clientSocket = try accept()
            logger.info("srtla-server: Accepted client with stream id \(acceptedStreamId).")
            recvLoop(clientSocket: clientSocket)
            logger.info("srtla-server: Closed client.")
        }
    }

    private func open() throws {
        listenerSocket = srt_create_socket()
        guard listenerSocket != SRT_ERROR else {
            throw "Failed to create SRT socket."
        }
    }

    private func bind() throws {
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout.size(ofValue: addr))
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_addr.s_addr = inet_addr("0.0.0.0")
        addr.sin_port = in_port_t(bigEndian: settings.srtPort)
        let addrSize = MemoryLayout.size(ofValue: addr)
        var res = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                srt_bind(listenerSocket, $0, Int32(addrSize))
            }
        }
        guard res != SRT_ERROR else {
            throw "SRT bind failed."
        }
    }

    private func listen() throws {
        var res = srt_listen(listenerSocket, 5)
        guard res != SRT_ERROR else {
            throw "SRT listen failed."
        }
        let server = Unmanaged.passRetained(self).toOpaque()
        res = srt_listen_callback(listenerSocket,
                                  { server, _, _, _, streamIdIn in
                                      guard let server, let streamIdIn else {
                                          return SRT_ERROR
                                      }
                                      let srtServer: SrtServer = Unmanaged.fromOpaque(server)
                                          .takeUnretainedValue()
                                      srtServer.acceptedStreamId = String(cString: streamIdIn)
                                      return 0
                                  },
                                  server)
        guard res != SRT_ERROR else {
            throw "SRT listen callback failed."
        }
    }

    private func accept() throws -> Int32 {
        let clientSocket = srt_accept(listenerSocket, nil, nil)
        guard clientSocket != SRT_ERROR else {
            throw "Accept failed."
        }
        return clientSocket
    }

    private func recvLoop(clientSocket: Int32) {
        let packetSize = 2048
        var packet = Data(count: packetSize)
        while true {
            let count = packet.withUnsafeMutableBytes { pointer in
                srt_recvmsg(clientSocket, pointer.baseAddress, Int32(packetSize))
            }
            guard count != SRT_ERROR else {
                break
            }
            logger.info("srtla-server: Got \(count) bytes.")
        }
        srt_close(clientSocket)
        logger.info("srtla-server: Closed client.")
    }
}
