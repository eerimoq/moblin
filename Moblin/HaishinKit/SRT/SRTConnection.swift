import Foundation
import libsrt

public class SRTConnection: NSObject {
    @objc public private(set) dynamic var connected = false

    var socket: SRTSocket? {
        didSet {
            socket?.delegate = self
        }
    }

    private var stream: SRTStream?
    var clients: [SRTSocket] = []
    private var sendHook: ((Data) -> Bool)?

    var performanceData: SRTPerformanceData {
        guard let socket else {
            return .zero
        }
        _ = socket.bstats()
        return SRTPerformanceData(mon: socket.perf)
    }

    override public init() {
        super.init()
        srt_startup()
    }

    deinit {
        removeStream()
        srt_cleanup()
    }

    func open(_ uri: URL?, sendHook: @escaping (Data) -> Bool, mode: SRTMode = .caller) throws {
        guard let uri = uri, let scheme = uri.scheme, let host = uri.host, let port = uri.port,
              scheme == "srt"
        else {
            return
        }
        self.sendHook = sendHook
        let options = SRTSocketOption.from(uri: uri)
        let addr = sockaddr_in(mode.host(host), port: UInt16(port))
        socket = .init()
        try socket?.open(addr, mode: mode, options: options)
    }

    /// Closes the connection from the server.
    func close() {
        for client in clients {
            client.close()
        }
        removeStream()
        socket?.close()
        socket = nil
        clients.removeAll()
        connected = false
    }

    func removeStream() {
        stream?.close()
        stream = nil
    }

    func setStream(stream: SRTStream) {
        self.stream = stream
    }

    private func sockaddr_in(_ host: String, port: UInt16) -> sockaddr_in {
        var addr: sockaddr_in = .init()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = CFSwapInt16BigToHost(UInt16(port))
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

extension SRTConnection: SRTSocketDelegate {
    func socket(_ socket: SRTSocket, status _: SRT_SOCKSTATUS) {
        connected = socket.status == SRTS_CONNECTED
    }

    func socket(_: SRTSocket, didAcceptSocket client: SRTSocket) {
        clients.append(client)
    }

    func socket(_: SRTSocket, sendHook data: Data) -> Bool {
        return sendHook?(data) ?? false
    }
}
