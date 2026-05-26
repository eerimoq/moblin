import AVFoundation
import libsrt

let srtClientQueue = DispatchQueue(label: "com.eerimoq.moblin.srt-client", qos: .userInteractive)

protocol SrtClientDelegate: AnyObject {
    func srtClientConnected(cameraId: UUID)
    func srtClientDisconnected(cameraId: UUID)
    func srtClientOnVideoBuffer(cameraId: UUID, _ sampleBuffer: CMSampleBuffer)
    func srtClientOnAudioBuffer(cameraId: UUID, _ sampleBuffer: CMSampleBuffer)
    func srtClientSetTargetLatencies(cameraId: UUID, _ videoTargetLatency: Double, _ audioTargetLatency: Double)
}

private let reconnectDelay = 5.0

class SrtClient: @unchecked Sendable {
    private let cameraId: UUID
    private let url: URL
    private let latency: Double
    private weak var delegate: (any SrtClientDelegate)?
    private var running = false
    private var socket: SRTSOCKET = SRT_INVALID_SOCK
    private var bitrateStats = BitrateStats()
    private var reconnectTimer = SimpleTimer(queue: srtClientQueue)
    private let reader: MpegTsReader

    init(cameraId: UUID, url: URL, latency: Double, delegate: any SrtClientDelegate) {
        self.cameraId = cameraId
        self.url = url
        self.latency = latency
        self.delegate = delegate
        reader = MpegTsReader(
            decoderQueue: srtClientQueue,
            timecodesEnabled: false,
            targetLatency: latency
        )
        reader.delegate = self
    }

    func start() {
        srt_startup()
        srtClientQueue.async {
            self.running = true
            self.connectSoon(delay: 0)
        }
    }

    func stop() {
        srtClientQueue.async {
            self.running = false
            self.reconnectTimer.stop()
            self.closeSocket()
        }
        srt_cleanup()
    }

    func updateStats() -> BitrateStatsInstant {
        srtClientQueue.sync {
            bitrateStats.update()
        }
    }

    private func connectSoon(delay: Double) {
        guard running else {
            return
        }
        reconnectTimer.startSingleShot(timeout: delay) { [weak self] in
            self?.connectAsync()
        }
    }

    private func connectAsync() {
        DispatchQueue(label: "com.eerimoq.moblin.srt-client-connection", qos: .userInteractive).async {
            self.connectAndReceive()
        }
    }

    private func connectAndReceive() {
        guard let host = url.host, let port = url.port else {
            logger.info("srt-client: \(cameraId): Invalid URL \(url).")
            srtClientQueue.async { self.connectSoon(delay: reconnectDelay) }
            return
        }
        // Capture the socket handle into a local so the receive loop (on this thread)
        // can use it independently from the management queue, allowing stop() to close
        // it from srtClientQueue while srt_recvmsg() is blocking on this thread.
        let sock: SRTSOCKET
        srtClientQueue.sync {
            socket = srt_create_socket()
            sock = socket
        }
        guard sock != SRT_INVALID_SOCK else {
            logger.info("srt-client: \(cameraId): Failed to create socket: \(lastSrtError())")
            srtClientQueue.async { self.connectSoon(delay: reconnectDelay) }
            return
        }
        let options = SrtSocketOption.from(uri: url)
        let failures = SrtSocketOption.configure(sock, binding: .pre, options: options)
        if !failures.isEmpty {
            logger.info("srt-client: \(cameraId): Failed to set pre-bind options: \(failures).")
        }
        var addr = sockaddrIn(host, port: UInt16(clamping: port))
        let addrSize = Int32(MemoryLayout.size(ofValue: addr))
        let result = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                srt_connect(sock, $0, addrSize)
            }
        }
        guard result != SRT_ERROR else {
            logger.info("srt-client: \(cameraId): Connect failed: \(lastSrtError())")
            srtClientQueue.async {
                self.clearSocket()
                self.connectSoon(delay: reconnectDelay)
            }
            return
        }
        let postFailures = SrtSocketOption.configure(sock, binding: .post, options: options)
        if !postFailures.isEmpty {
            logger.info("srt-client: \(cameraId): Failed to set post-bind options: \(postFailures).")
        }
        logger.info("srt-client: \(cameraId): Connected to \(host):\(port).")
        let stillRunning = srtClientQueue.sync { running }
        if stillRunning {
            delegate?.srtClientConnected(cameraId: cameraId)
            receive(sock: sock)
        }
        logger.info("srt-client: \(cameraId): Disconnected from \(host):\(port).")
        let wasRunning = srtClientQueue.sync {
            clearSocket()
            return running
        }
        if wasRunning {
            delegate?.srtClientDisconnected(cameraId: cameraId)
            srtClientQueue.async { self.connectSoon(delay: reconnectDelay) }
        }
    }

    private func receive(sock: SRTSOCKET) {
        let packetSize = 2048
        nonisolated(unsafe)
        var packet = Data(count: packetSize)
        while true {
            packet.count = packetSize
            let count = packet.withUnsafeMutableBytes { pointer in
                srt_recvmsg(sock, pointer.baseAddress, Int32(packetSize))
            }
            guard count != SRT_ERROR else {
                break
            }
            packet.count = Int(count)
            srtClientQueue.async {
                self.bitrateStats.add(bytesTransferred: Int(count))
            }
            do {
                try reader.handlePacketFromClient(packet: packet)
            } catch {
                logger.info("srt-client: \(cameraId): Got corrupt packet: \(error).")
            }
        }
    }

    // Called only from srtClientQueue.
    private func closeSocket() {
        guard socket != SRT_INVALID_SOCK else {
            return
        }
        srt_close(socket)
        socket = SRT_INVALID_SOCK
    }

    // Clears socket reference without closing (already closed by receive end).
    // Called only from srtClientQueue.
    private func clearSocket() {
        socket = SRT_INVALID_SOCK
    }

    private func sockaddrIn(_ host: String, port: UInt16) -> sockaddr_in {
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = CFSwapInt16BigToHost(port)
        if inet_pton(AF_INET, host, &addr.sin_addr) == 1 {
            return addr
        }
        guard let hostent = gethostbyname(host), hostent.pointee.h_addrtype == AF_INET else {
            return addr
        }
        addr.sin_addr = UnsafeRawPointer(hostent.pointee.h_addr_list[0]!)
            .assumingMemoryBound(to: in_addr.self).pointee
        return addr
    }
}

extension SrtClient: MpegTsReaderDelegate {
    func mpegTsReaderVideoBuffer(_ sampleBuffer: CMSampleBuffer) {
        delegate?.srtClientOnVideoBuffer(cameraId: cameraId, sampleBuffer)
    }

    func mpegTsReaderAudioBuffer(_ sampleBuffer: CMSampleBuffer) {
        delegate?.srtClientOnAudioBuffer(cameraId: cameraId, sampleBuffer)
    }

    func mpegTsReaderSetTargetLatencies(_ videoTargetLatency: Double, _ audioTargetLatency: Double) {
        delegate?.srtClientSetTargetLatencies(cameraId: cameraId, videoTargetLatency, audioTargetLatency)
    }
}

private func lastSrtError() -> String {
    String(cString: srt_getlasterror_str())
}
