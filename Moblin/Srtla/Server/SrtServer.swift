import AVFoundation
import libsrt

private let srtServerQueue = DispatchQueue(label: "com.eerimoq.srtla-srt-server")

class SrtServer {
    weak var srtlaServer: SrtlaServer?
    private var listenerSocket: SRTSOCKET = SRT_INVALID_SOCK
    private var acceptedStreamId = ""
    var running: Bool = false
    var totalBytesReceived: Atomic<UInt64> = .init(0)
    var numberOfClients: Atomic<Int> = .init(0)

    func start() {
        srt_startup()
        running = true
        srtServerQueue.async {
            do {
                try self.main()
            } catch {
                logger.info("srt-server: \(error)")
            }
        }
    }

    func stop() {
        srt_close(listenerSocket)
        listenerSocket = SRT_INVALID_SOCK
        running = false
        srt_cleanup()
    }

    private func main() throws {
        try open()
        try bind()
        try listen()
        while true {
            logger.info("srt-server: Waiting for client to connect.")
            let clientSocket = try accept()
            guard let stream = srtlaServer?.settings.streams
                .first(where: { $0.streamId == acceptedStreamId })
            else {
                srt_close(clientSocket)
                logger.info("srt-server: Client with stream id \(acceptedStreamId) denied.")
                continue
            }
            // Makes NAK too slow?
            let option = SRTSocketOption(rawValue: "lossmaxttl")!
            if !option.setOption(clientSocket, value: "200") {
                logger.error("srt-server: Failed to set lossmaxttl option.")
            }
            logger.info("srt-server: Accepted client \(stream.name).")
            numberOfClients.mutate { $0 += 1 }
            SrtServerClient(server: self, streamId: acceptedStreamId).run(clientSocket: clientSocket)
            numberOfClients.mutate { $0 -= 1 }
            logger.info("srt-server: Closed client.")
        }
    }

    private func open() throws {
        listenerSocket = srt_create_socket()
        guard listenerSocket != SRT_ERROR else {
            throw "Failed to create socket."
        }
    }

    private func bind() throws {
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout.size(ofValue: addr))
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_addr.s_addr = inet_addr("0.0.0.0")
        addr.sin_port = in_port_t(bigEndian: srtlaServer?.settings.srtPort ?? 4000)
        let addrSize = MemoryLayout.size(ofValue: addr)
        let res = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                srt_bind(listenerSocket, $0, Int32(addrSize))
            }
        }
        guard res != SRT_ERROR else {
            throw "Bind failed."
        }
    }

    private func listen() throws {
        var res = srt_listen(listenerSocket, 5)
        guard res != SRT_ERROR else {
            throw "Listen failed."
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
            throw "Listen callback failed."
        }
    }

    private func accept() throws -> Int32 {
        let clientSocket = srt_accept(listenerSocket, nil, nil)
        guard clientSocket != SRT_ERROR else {
            throw "Accept failed."
        }
        return clientSocket
    }
}
