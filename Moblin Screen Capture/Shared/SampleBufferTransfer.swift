import AVFoundation
import ReplayKit

// | 4b header size | <m>b header | <n>b buffer |

private struct Header: Codable {
    var bufferType: Int
    var bufferSize: Int
    // periphery:ignore
    var width: Int32
    // periphery:ignore
    var height: Int32
}

private func createContainerDir(appGroup: String) throws -> URL {
    guard let containerDir = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: appGroup)
    else {
        throw "Failed to create container directory"
    }
    try FileManager.default.createDirectory(at: containerDir, withIntermediateDirectories: true)
    return containerDir
}

private func createSocketPath(containerDir: URL) -> URL {
    return containerDir.appendingPathComponent("sb.sock")
}

private func removeFile(path: URL) {
    do {
        try FileManager.default.removeItem(at: path)
    } catch {}
}

private func createAddr(path: URL) throws -> sockaddr_un {
    let path = path.path
    var addr = sockaddr_un()
    addr.sun_family = sa_family_t(AF_UNIX)
    let pathLength = path.withCString { Int(strlen($0)) }
    guard MemoryLayout.size(ofValue: addr.sun_path) > pathLength else {
        throw "sample-buffer: unix socket path \(path) too long"
    }
    _ = withUnsafeMutablePointer(to: &addr.sun_path.0) { addrPtr in
        path.withCString {
            strncpy(addrPtr, $0, pathLength)
        }
    }
    return addr
}

private func socket() throws -> Int32 {
    let fd = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
    if fd == -1 {
        throw "Failed to create unix socket"
    }
    return fd
}

private func setIgnoreSigPipe(fd: Int32) throws {
    var on: Int32 = 1
    if setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size)) == -1 {
        throw "Failed to set ignore sigpipe"
    }
}

private func connect(fd: Int32, addr: sockaddr_un) throws {
    var addr = addr
    let res = withUnsafePointer(to: &addr) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            Darwin.connect(fd, $0, UInt32(MemoryLayout<sockaddr_un>.stride))
        }
    }
    if res == -1 {
        throw "Failed to connect"
    }
}

private func bind(fd: Int32, addr: sockaddr_un) throws {
    var addr = addr
    let res = withUnsafePointer(to: &addr) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            Darwin.bind(fd, $0, UInt32(MemoryLayout<sockaddr_un>.stride))
        }
    }
    if res == -1 {
        throw "Failed to bind"
    }
}

private func listen(fd: Int32) throws {
    if Darwin.listen(fd, 5) == -1 {
        throw "Failed to listen"
    }
}

private func accept(fd: Int32) throws -> Int32 {
    let senderFd = Darwin.accept(fd, nil, nil)
    if senderFd == -1 {
        throw "Failed to accept"
    }
    return senderFd
}

// periphery:ignore
class SampleBufferSender {
    private var fd: Int32

    init() {
        fd = -1
    }

    func start(appGroup: String) {
        do {
            fd = try socket()
            try setIgnoreSigPipe(fd: fd)
            let containerDir = try createContainerDir(appGroup: appGroup)
            let path = createSocketPath(containerDir: containerDir)
            let addr = try createAddr(path: path)
            try connect(fd: fd, addr: addr)
        } catch {}
    }

    func stop() {
        Darwin.close(fd)
    }

    func send(_ sampleBuffer: CMSampleBuffer, _ type: RPSampleBufferType) {
        if type == .video {
            try? sendVideo(sampleBuffer, type)
        } else {
            try? sendAudio(sampleBuffer, type)
        }
    }

    private func sendVideo(_ sampleBuffer: CMSampleBuffer, _ type: RPSampleBufferType) throws {
        guard let formatDescription = sampleBuffer.formatDescription,
              let imageBuffer = sampleBuffer.imageBuffer
        else {
            return
        }
        let bufferSize = CVPixelBufferGetDataSize(imageBuffer)
        let header = Header(bufferType: type.rawValue,
                            bufferSize: bufferSize,
                            width: formatDescription.dimensions.width,
                            height: formatDescription.dimensions.height)
        guard (try? sendHeader(header)) != nil else {
            return
        }
        CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly)
        }
        guard let pointer = CVPixelBufferGetBaseAddress(imageBuffer) else {
            return
        }
        try send(pointer: UnsafeRawBufferPointer(start: UnsafeRawPointer(pointer), count: bufferSize))
    }

    private func sendAudio(_ sampleBuffer: CMSampleBuffer, _ type: RPSampleBufferType) throws {
        guard let dataBuffer = sampleBuffer.dataBuffer else {
            return
        }
        guard let data = try? dataBuffer.dataBytes() else {
            return
        }
        let header = Header(
            bufferType: type.rawValue,
            bufferSize: data.count,
            width: 0,
            height: 0
        )
        guard (try? sendHeader(header)) != nil else {
            return
        }
        try send(data: data)
    }

    private func sendHeader(_ header: Header) throws {
        let encoder = PropertyListEncoder()
        let data = try encoder.encode(header)
        try send(data: Data([
            UInt8((data.count >> 24) & 0xFF),
            UInt8((data.count >> 16) & 0xFF),
            UInt8((data.count >> 8) & 0xFF),
            UInt8((data.count >> 0) & 0xFF),
        ]))
        try send(data: data)
    }

    private func send(data: Data) throws {
        try data.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
            try send(pointer: pointer)
        }
    }

    private func send(pointer: UnsafeRawBufferPointer) throws {
        guard let basePointer = pointer.baseAddress else {
            return
        }
        var offset = 0
        while offset < pointer.count {
            let res = Darwin.write(fd, basePointer.advanced(by: offset), pointer.count - offset)
            if res == -1 {
                throw "Send failed"
            }
            offset += res
        }
    }
}

protocol SampleBufferReceiverDelegate: AnyObject {
    func senderConnected()
    func senderDisconnected()
    func handleSampleBuffer(sampleBuffer: CMSampleBuffer?, type: RPSampleBufferType)
}

class SampleBufferReceiver {
    private var listenerFd: Int32
    weak var delegate: (any SampleBufferReceiverDelegate)?

    init() {
        listenerFd = -1
    }

    func start(appGroup: String) {
        do {
            listenerFd = try socket()
            try setIgnoreSigPipe(fd: listenerFd)
            let containerDir = try createContainerDir(appGroup: appGroup)
            let path = createSocketPath(containerDir: containerDir)
            removeFile(path: path)
            let addr = try createAddr(path: path)
            try bind(fd: listenerFd, addr: addr)
            try listen(fd: listenerFd)
        } catch {
            return
        }
        DispatchQueue.global(qos: .userInteractive).async {
            try? self.acceptLoop()
        }
    }

    // periphery:ignore
    func stop() {}

    private func acceptLoop() throws {
        while true {
            let senderFd = try accept(fd: listenerFd)
            try setIgnoreSigPipe(fd: senderFd)
            delegate?.senderConnected()
            try? readLoop(senderFd: senderFd)
            delegate?.senderDisconnected()
        }
    }

    private func readLoop(senderFd: Int32) throws {
        while true {
            let headerSizeData = try read(senderFd: senderFd, count: 4)
            let headerSize = (Int(headerSizeData[0]) << 24) |
                (Int(headerSizeData[1]) << 16) |
                (Int(headerSizeData[2]) << 8) |
                (Int(headerSizeData[3]) << 0)
            let headerData = try read(senderFd: senderFd, count: headerSize)
            let decoder = PropertyListDecoder()
            let header = try decoder.decode(Header.self, from: headerData)
            let data = try read(senderFd: senderFd, count: header.bufferSize)
            guard let type = RPSampleBufferType(rawValue: header.bufferType) else {
                break
            }
            delegate?.handleSampleBuffer(sampleBuffer: nil, type: type)
        }
    }

    private func read(senderFd: Int32, count: Int) throws -> Data {
        var data = Data(count: count)
        var offset = 0
        try data.withUnsafeMutableBytes { (pointer: UnsafeMutableRawBufferPointer) in
            guard let baseAddress = pointer.baseAddress else {
                throw "No base address"
            }
            while offset < count {
                let readCount = Darwin.read(senderFd, baseAddress.advanced(by: offset), count - offset)
                if readCount <= 0 {
                    throw "Closed"
                }
                offset += readCount
            }
        }
        return data
    }
}
