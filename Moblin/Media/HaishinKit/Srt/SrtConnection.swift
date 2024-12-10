import Foundation
import libsrt

public class SrtConnection: NSObject {
    @objc public private(set) dynamic var connected = false

    var socket: SrtSocket? {
        didSet {
            socket?.delegate = self
        }
    }

    private var stream: SrtStream?
    private var sendHook: ((Data) -> Bool)?

    var performanceData: SrtPerformanceData {
        guard let socket else {
            return .zero
        }
        _ = socket.bstats()
        return SrtPerformanceData(mon: socket.perf)
    }

    override public init() {
        super.init()
        srt_startup()
    }

    deinit {
        removeStream()
        srt_cleanup()
    }

    func open(_ uri: URL?, sendHook: @escaping (Data) -> Bool) throws {
        guard let uri, uri.scheme == "srt", let host = uri.host, let port = uri.port else {
            return
        }
        self.sendHook = sendHook
        socket = .init()
        try socket?.open(sockaddrIn(host, port: UInt16(port)), SrtSocketOption.from(uri: uri))
    }

    func close() {
        removeStream()
        socket?.close()
        socket = nil
        connected = false
    }

    func removeStream() {
        stream?.close()
        stream = nil
    }

    func setStream(stream: SrtStream) {
        self.stream = stream
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

extension SrtConnection: SrtSocketDelegate {
    func socket(_ socket: SrtSocket, status _: SRT_SOCKSTATUS) {
        connected = socket.status == SRTS_CONNECTED
    }

    func socket(_: SrtSocket, sendHook data: Data) -> Bool {
        return sendHook?(data) ?? false
    }
}
