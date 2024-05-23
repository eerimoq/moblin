import AVFoundation

// | 4b header size | <m>b header | <n>b buffer |

// periphery:ignore
private struct Header: Codable {
    var bufferType: Int
    var bufferSize: Int
    var width: Int
    var height: Int
}

private func createAddr(path: String) -> sockaddr_un? {
    var addr = sockaddr_un()
    addr.sun_family = sa_family_t(AF_UNIX)
    let pathLength = path.withCString { Int(strlen($0)) }
    guard pathLength < MemoryLayout.size(ofValue: addr.sun_path) else {
        return nil
    }
    _ = withUnsafeMutablePointer(to: &addr.sun_path.0) { addrPtr in
        path.withCString {
            strncpy(addrPtr, $0, pathLength)
        }
    }
    return addr
}

private func setIgnoreSigPipe(fd: Int32) -> Bool {
    var on: Int32 = 1
    return setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size)) != -1
}

private func connect(fd: Int32, addr: sockaddr_un) -> Bool {
    var addr = addr
    let res = withUnsafePointer(to: &addr) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            Darwin.connect(fd, $0, UInt32(MemoryLayout<sockaddr_un>.stride))
        }
    }
    return res != -1
}

private func bind(fd: Int32, addr: sockaddr_un) -> Bool {
    var addr = addr
    let res = withUnsafePointer(to: &addr) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            Darwin.bind(fd, $0, UInt32(MemoryLayout<sockaddr_un>.stride))
        }
    }
    return res != -1
}

// periphery:ignore
class SampleBufferSender {
    private var fd: Int32

    init() {
        fd = -1
    }

    func start(path: String) {
        fd = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        if fd == -1 {
            logger.info("sample-buffer-sender: Failed to create unix socket")
            return
        }
        if !setIgnoreSigPipe(fd: fd) {
            logger.info("sample-buffer-sender: Failed to set ignore sigpipe")
            return
        }
        guard let addr = createAddr(path: path) else {
            logger.info("sample-buffer-sender: Failed to create socket address")
            return
        }
        if !connect(fd: fd, addr: addr) {
            logger.info("sample-buffer-sender: Failed to connect")
            return
        }
    }

    func stop() {}

    func send(sampleBuffer _: CMSampleBuffer) {}
}

// periphery:ignore
protocol SampleBufferReceiverDelegate: AnyObject {
    func handleSampleBuffer(sampleBuffer: CMSampleBuffer)
}

// periphery:ignore
class SampleBufferReceiver {
    private var listenerFd: Int32
    weak var delegate: (any SampleBufferReceiverDelegate)?

    init() {
        listenerFd = -1
    }

    func start(path: String) {
        listenerFd = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        if listenerFd == -1 {
            logger.info("sample-buffer-receiver: Failed to create unix socket")
            return
        }
        if !setIgnoreSigPipe(fd: listenerFd) {
            logger.info("sample-buffer-receiver: Failed to set ignore sigpipe")
            return
        }
        guard let addr = createAddr(path: path) else {
            logger.info("sample-buffer-receiver: Failed to create socket address")
            return
        }
        if !bind(fd: listenerFd, addr: addr) {
            logger.info("sample-buffer-receiver: Failed to bind")
            return
        }
        if Darwin.listen(listenerFd, 5) == -1 {
            logger.info("sample-buffer-receiver: Failed to listen")
            return
        }
        DispatchQueue.global(qos: .userInteractive).async {
            while true {
                let senderFd = Darwin.accept(self.listenerFd, nil, nil)
                if senderFd == -1 {
                    logger.info("sample-buffer-receiver: Failed to accept")
                    break
                }
                if !setIgnoreSigPipe(fd: senderFd) {
                    logger.info("sample-buffer-receiver: Failed to set ignore sigpipe")
                    break
                }
                logger.info("sample-buffer-receiver: Sender connected")
            }
        }
    }

    func stop() {}
}
