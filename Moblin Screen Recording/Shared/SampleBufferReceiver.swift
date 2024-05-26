import AVFoundation
import ReplayKit

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
            listenerFd = try createSocket()
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
            let header = try readHeader(senderFd: senderFd)
            let data = try read(senderFd: senderFd, count: header.bufferSize)
            guard let type = RPSampleBufferType(rawValue: header.bufferType) else {
                break
            }
            switch type {
            case .video:
                handleVideo(header, data)
            case .audioApp:
                handleAudio(header, data)
            default:
                break
            }
            delegate?.handleSampleBuffer(sampleBuffer: nil, type: type)
        }
    }

    private func handleVideo(_: SampleBufferHeader, _: Data) {}

    private func handleAudio(_: SampleBufferHeader, _: Data) {}

    private func readHeader(senderFd: Int32) throws -> SampleBufferHeader {
        let sizeData = try read(senderFd: senderFd, count: 4)
        let size = Int(sizeData.getUInt32Be())
        let data = try read(senderFd: senderFd, count: size)
        return try PropertyListDecoder().decode(SampleBufferHeader.self, from: data)
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
