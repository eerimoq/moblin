import AVFoundation
import libsrt

private let srtClientQueue = DispatchQueue(label: "com.eerimoq.moblin.srt-client",
                                           qos: .userInteractive)

protocol SrtClientDelegate: AnyObject {
    func srtClientConnected(cameraId: UUID)
    func srtClientDisconnected(cameraId: UUID)
    func srtClientOnVideoBuffer(cameraId: UUID, _ sampleBuffer: CMSampleBuffer)
    func srtClientOnAudioBuffer(cameraId: UUID, _ sampleBuffer: CMSampleBuffer)
    func srtClientSetTargetLatencies(cameraId: UUID,
                                     _ videoTargetLatency: Double,
                                     _ audioTargetLatency: Double)
}

let srtClientLatency = 0.5
private let reconnectDelay = 5.0

class SrtClient: @unchecked Sendable {
    private let cameraId: UUID
    private let url: URL
    private weak var delegate: (any SrtClientDelegate)?
    private var running = false
    private var socket: SRTSOCKET = SRT_INVALID_SOCK
    private var bitrateStats: Atomic<BitrateStats> = .init(.init())
    private let reconnectTimer = SimpleTimer(queue: srtClientQueue)
    private let reader: MpegTsReader

    init(cameraId: UUID, url: URL, delegate: any SrtClientDelegate) {
        self.cameraId = cameraId
        self.url = url
        self.delegate = delegate
        reader = MpegTsReader(
            decoderQueue: srtClientQueue,
            timecodesEnabled: false,
            targetLatency: srtClientLatency
        )
        reader.delegate = self
    }

    func start() {
        srtClientQueue.async {
            srt_startup()
            self.running = true
            self.connectSoon(delay: 0)
        }
    }

    func stop() {
        srtClientQueue.async {
            self.running = false
            self.reconnectTimer.stop()
            self.closeSocket()
            srt_cleanup()
        }
    }

    func updateStats() -> BitrateStatsInstant {
        nonisolated(unsafe) var stats: BitrateStatsInstant?
        bitrateStats.mutate {
            stats = $0.update()
        }
        return stats!
    }

    private func connectSoon(delay: Double) {
        closeSocket()
        guard running else {
            return
        }
        reconnectTimer.startSingleShot(timeout: delay) { [weak self] in
            self?.connectAsync()
        }
    }

    private func connectAsync() {
        let socket = srt_create_socket()
        guard socket != SRT_INVALID_SOCK else {
            logger.info("srt-client: \(cameraId): Failed to create socket: \(lastSrtError())")
            srtClientQueue.async {
                self.connectSoon(delay: reconnectDelay)
            }
            return
        }
        self.socket = socket
        DispatchQueue(label: "com.eerimoq.moblin.srt-client-connection", qos: .userInteractive).async {
            self.main(socket: socket)
        }
    }

    private func main(socket: SRTSOCKET) {
        guard let host = url.host, let port = url.port else {
            logger.info("srt-client: \(cameraId): Invalid URL \(url).")
            srtClientQueue.async {
                self.connectSoon(delay: reconnectDelay)
            }
            return
        }
        let options = SrtSocketOption.from(uri: url)
        let failures = SrtSocketOption.configure(socket, binding: .pre, options: options)
        if !failures.isEmpty {
            logger.info("srt-client: \(cameraId): Failed to set pre-bind options: \(failures).")
        }
        var address = sockaddrIn(host, port: UInt16(clamping: port))
        let addressSize = Int32(MemoryLayout.size(ofValue: address))
        let result = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                srt_connect(socket, $0, addressSize)
            }
        }
        guard result != SRT_ERROR else {
            logger.info("srt-client: \(cameraId): Connect failed: \(lastSrtError())")
            srtClientQueue.async {
                self.connectSoon(delay: reconnectDelay)
            }
            return
        }
        let postFailures = SrtSocketOption.configure(socket, binding: .post, options: options)
        if !postFailures.isEmpty {
            logger.info("srt-client: \(cameraId): Failed to set post-bind options: \(postFailures).")
        }
        delegate?.srtClientConnected(cameraId: cameraId)
        receive(socket: socket)
        delegate?.srtClientDisconnected(cameraId: cameraId)
        srtClientQueue.async {
            self.connectSoon(delay: reconnectDelay)
        }
    }

    private func receive(socket: SRTSOCKET) {
        let packetSize = 2048
        nonisolated(unsafe)
        var packet = Data(count: packetSize)
        while true {
            packet.count = packetSize
            let count = packet.withUnsafeMutableBytes { pointer in
                srt_recvmsg(socket, pointer.baseAddress, Int32(packetSize))
            }
            guard count != SRT_ERROR else {
                break
            }
            packet.count = Int(count)
            bitrateStats.mutate {
                $0.add(bytesTransferred: Int(count))
            }
            do {
                try reader.handlePacketFromClient(packet: packet)
            } catch {
                logger.info("srt-client: \(cameraId): Got corrupt packet: \(error).")
            }
        }
    }

    private func closeSocket() {
        guard socket != SRT_INVALID_SOCK else {
            return
        }
        srt_close(socket)
        socket = SRT_INVALID_SOCK
    }
}

private func sockaddrIn(_ host: String, port: UInt16) -> sockaddr_in {
    var addr = sockaddr_in()
    addr.sin_family = sa_family_t(AF_INET)
    addr.sin_port = in_port_t(bigEndian: port)
    guard let hostent = gethostbyname(host), hostent.pointee.h_addrtype == AF_INET else {
        return addr
    }
    addr.sin_addr = UnsafeRawPointer(hostent.pointee.h_addr_list[0]!)
        .assumingMemoryBound(to: in_addr.self).pointee
    return addr
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
