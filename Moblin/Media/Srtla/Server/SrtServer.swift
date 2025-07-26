import AVFoundation
import libsrt

class SrtServer {
    weak var srtlaServer: SrtlaServer?
    private var listenerSocket: SRTSOCKET = SRT_INVALID_SOCK
    var acceptedStreamId: Atomic<String> = .init("")
    var running: Bool = false
    private let timecodesEnabled: Bool
    private let port: UInt16
    private let srtlaPatches: Bool

    init(timecodesEnabled: Bool, port: UInt16, srtlaPatches: Bool) {
        self.timecodesEnabled = timecodesEnabled
        self.port = port
        self.srtlaPatches = srtlaPatches
    }

    func start() {
        srt_startup()
        running = true
        DispatchQueue(label: "com.eerimoq.srtla-srt-server", qos: .userInteractive).async {
            do {
                try self.main()
            } catch {
                logger.info("srt-server: \(self.port): \(error)")
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
        if srtlaPatches {
            logger.info("srt-server: \(port): Enabling SRTLA patches.")
            try setSrtlaPatchesOption()
            try setLossMaxTtlOption()
        }
        try bind()
        try listen()
        while true {
            logger.info("srt-server: \(port): Waiting for client to connect.")
            let clientSocket = try accept()
            guard let srtlaServer,
                  let stream = srtlaServer.settings.streams.first(where: { $0.streamId == acceptedStreamId.value }),
                  !srtlaServer.connectedStreamIds.value.contains(acceptedStreamId.value)
            else {
                srt_close(clientSocket)
                logger.info("srt-server: \(port): Client with stream id \(acceptedStreamId.value) denied.")
                continue
            }
            logger.info("srt-server: \(port): Accepted client \(stream.name).")
            let streamId = acceptedStreamId.value
            DispatchQueue(label: "com.eerimoq.Moblin.SrtClient").async {
                srtlaServer.connectedStreamIds.mutate { $0.append(streamId) }
                srtlaServer.clientConnected(streamId: streamId)
                SrtServerClient(server: self, streamId: streamId, timecodesEnabled: self.timecodesEnabled)
                    .run(clientSocket: clientSocket)
                srtlaServer.connectedStreamIds.mutate { $0.removeAll(where: { $0 == streamId }) }
                srtlaServer.clientDisconnected(streamId: streamId)
                logger.info("srt-server: \(self.port): Closed client.")
            }
            acceptedStreamId.mutate { $0 = "" }
        }
    }

    private func open() throws {
        listenerSocket = srt_create_socket()
        guard listenerSocket != SRT_ERROR else {
            throw "Failed to create socket: \(lastSrtSocketError())"
        }
    }

    private func setSrtlaPatchesOption() throws {
        let srtlaPatches = SrtSocketOption(rawValue: "srtlaPatches")!
        guard srtlaPatches.setOption(listenerSocket, value: "1") else {
            throw "Failed to set srtlaPatches option."
        }
    }

    private func setLossMaxTtlOption() throws {
        // Makes NAK too slow?
        let option = SrtSocketOption(rawValue: "lossmaxttl")!
        if !option.setOption(listenerSocket, value: "30") {
            logger.error("srt-server: \(port): Failed to set lossmaxttl option.")
        }
    }

    private func bind() throws {
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout.size(ofValue: addr))
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_addr.s_addr = inet_addr("0.0.0.0")
        addr.sin_port = in_port_t(bigEndian: port)
        let addrSize = MemoryLayout.size(ofValue: addr)
        let res = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                srt_bind(listenerSocket, $0, Int32(addrSize))
            }
        }
        guard res != SRT_ERROR else {
            throw "Bind failed: \(lastSrtSocketError())"
        }
    }

    private func listen() throws {
        var res = srt_listen(listenerSocket, 5)
        guard res != SRT_ERROR else {
            throw "Listen failed: \(lastSrtSocketError())"
        }
        let server = Unmanaged.passRetained(self).toOpaque()
        res = srt_listen_callback(
            listenerSocket,
            { server, _, _, _, streamIdIn in
                guard let server, let streamIdIn else {
                    return SRT_ERROR
                }
                let srtServer: SrtServer = Unmanaged.fromOpaque(server)
                    .takeUnretainedValue()
                srtServer.acceptedStreamId.mutate { $0 = String(cString: streamIdIn) }
                return 0
            },
            server
        )
        guard res != SRT_ERROR else {
            throw "Listen callback failed: \(lastSrtSocketError())"
        }
    }

    private func accept() throws -> Int32 {
        let clientSocket = srt_accept(listenerSocket, nil, nil)
        guard clientSocket != SRT_ERROR else {
            throw "Accept failed: \(lastSrtSocketError())"
        }
        return clientSocket
    }
}

private func lastSrtSocketError() -> String {
    return String(cString: srt_getlasterror_str())
}
