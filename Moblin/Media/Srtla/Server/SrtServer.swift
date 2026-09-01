import AVFoundation
import libsrt

class SrtServer: @unchecked Sendable {
    weak var srtlaServer: SrtlaServer?
    private var listenerSocket: SRTSOCKET = SRT_INVALID_SOCK
    var running: Bool = false
    private let timecodesEnabled: Bool
    private let softwareDecoding: Bool
    private let port: UInt16
    private let srtlaPatches: Bool

    init(timecodesEnabled: Bool, softwareDecoding: Bool, port: UInt16, srtlaPatches: Bool) {
        self.timecodesEnabled = timecodesEnabled
        self.softwareDecoding = softwareDecoding
        self.port = port
        self.srtlaPatches = srtlaPatches
    }

    func start() {
        srt_startup()
        running = true
        startBlockingThread(name: "com.eerimoq.srtla-srt-server") {
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
            let streamId = getStreamId(clientSocket)
            guard let srtlaServer,
                  let stream = srtlaServer.settings.streams
                  .first(where: { $0.streamId == streamId }),
                  !srtlaServer.connectedStreamIds.value.contains(streamId)
            else {
                srt_close(clientSocket)
                logger.info("srt-server: \(port): Client with stream id '\(streamId)' denied.")
                continue
            }
            logger.info("srt-server: \(port): Accepted client \(stream.name).")
            let cameraId = stream.id
            let name = stream.camera()
            startBlockingThread(name: "com.eerimoq.Moblin.SrtClient") {
                srtlaServer.connectedStreamIds.mutate { $0.append(streamId) }
                srtlaServer.clientConnected(cameraId: cameraId, name: name)
                SrtServerClient(server: self,
                                cameraId: cameraId,
                                timecodesEnabled: self.timecodesEnabled,
                                softwareDecoding: self.softwareDecoding)
                    .run(clientSocket: clientSocket)
                srtlaServer.connectedStreamIds.mutate { $0.removeAll(where: { $0 == streamId }) }
                srtlaServer.clientDisconnected(cameraId: cameraId, name: name)
                logger.info("srt-server: \(self.port): Closed client.")
            }
        }
    }

    private func getStreamId(_ socket: SRTSOCKET) -> String {
        var streamId = [CChar](repeating: 0, count: 513)
        var size = Int32(512)
        guard srt_getsockflag(socket, SRTO_STREAMID, &streamId, &size) != SRT_ERROR else {
            return ""
        }
        return String(cString: streamId)
    }

    private func open() throws {
        listenerSocket = srt_create_socket()
        guard listenerSocket != SRT_INVALID_SOCK else {
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
            logger.info("srt-server: \(port): Failed to set lossmaxttl option.")
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
        guard srt_listen(listenerSocket, 5) != SRT_ERROR else {
            throw "Listen failed: \(lastSrtSocketError())"
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
    String(cString: srt_getlasterror_str())
}
