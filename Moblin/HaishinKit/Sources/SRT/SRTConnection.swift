import Foundation
import libsrt

/// The SRTConnection class create a two-way SRT connection.
public class SRTConnection: NSObject {
    /// SRT Library version
    public static let version: String = SRT_VERSION_STRING
    /// The URI passed to the SRTConnection.connect() method.
    public private(set) var uri: URL?
    /// This instance connect to server(true) or not(false)
    @objc public private(set) dynamic var connected = false

    var socket: SRTSocket? {
        didSet {
            socket?.delegate = self
        }
    }

    private var stream: SRTStream?
    var clients: [SRTSocket] = []
    private var sendHook: ((Data) -> Bool)?

    /// The SRT's performance data.
    public var performanceData: SRTPerformanceData {
        guard let socket else {
            return .zero
        }
        _ = socket.bstats()
        return SRTPerformanceData(mon: socket.perf)
    }

    /// Creates a new SRTConnection.
    override public init() {
        super.init()
        srt_startup()
    }

    deinit {
        removeStream()
        srt_cleanup()
    }

    /// Open a two-way connection to an application on SRT Server.
    public func open(_ uri: URL?, sendHook: @escaping (Data) -> Bool, mode: SRTMode = .caller) throws {
        guard let uri = uri, let scheme = uri.scheme, let host = uri.host, let port = uri.port,
              scheme == "srt"
        else {
            return
        }
        self.uri = uri
        self.sendHook = sendHook
        let options = SRTSocketOption.from(uri: uri)
        let addr = sockaddr_in(mode.host(host), port: UInt16(port))
        socket = .init()
        try socket?.open(addr, mode: mode, options: options)
    }

    /// Closes the connection from the server.
    public func close() {
        for client in clients {
            client.close()
        }
        removeStream()
        socket?.close()
        socket = nil
        clients.removeAll()
        connected = false
    }

    public func setOption(name: String, value: String) {
        let uri = URL(string: "https:///?\(name)=\(value)")
        let options = SRTSocketOption.from(uri: uri)
        if let socket {
            let failures = SRTSocketOption.configure(socket.socket,
                                                     binding: .post,
                                                     options: options)
            if !failures.isEmpty {
                logger.error("set option failure: \(failures)")
            }
        } else {
            logger.info("No socket")
        }
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
