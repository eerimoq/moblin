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
    func handleSampleBuffer(type: RPSampleBufferType, sampleBuffer: CMSampleBuffer)
}

class SampleBufferReceiver {
    private var listenerFd: Int32
    weak var delegate: (any SampleBufferReceiverDelegate)?
    private var videoBufferPool: CVPixelBufferPool?

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
        videoBufferPool = nil
        while true {
            let header = try readHeader(senderFd)
            guard let type = RPSampleBufferType(rawValue: header.bufferType) else {
                break
            }
            let sampleBuffer: CMSampleBuffer?
            switch type {
            case .video:
                sampleBuffer = try handleVideo(senderFd, header)
            case .audioApp:
                sampleBuffer = try handleAudio(senderFd, header)
            default:
                continue
            }
            guard let sampleBuffer else {
                continue
            }
            delegate?.handleSampleBuffer(type: type, sampleBuffer: sampleBuffer)
        }
    }

    private func handleVideo(_ senderFd: Int32, _ header: SampleBufferHeader) throws -> CMSampleBuffer {
        let pixelBufferPool = try getVideoBufferPool(header)
        let pixelBuffer = try createPixelBuffer(pool: pixelBufferPool)
        CVPixelBufferLockBaseAddress(pixelBuffer, .init(rawValue: 0))
        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .init(rawValue: 0))
        }
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            throw "Failed to get base address"
        }
        let size = CVPixelBufferGetDataSize(pixelBuffer)
        try readPointer(senderFd, baseAddress, size)
        // To do: Figure out why not all frame data fits in the buffer.
        if header.bufferSize > size {
            _ = try read(senderFd, header.bufferSize - size)
        }
        guard let formatDescription = CMVideoFormatDescription.create(imageBuffer: pixelBuffer)
        else {
            throw "Failed to create format description"
        }
        guard let sampleBuffer = CMSampleBuffer.create(
            pixelBuffer,
            formatDescription,
            .invalid,
            header.presentationTimeStamp.toCMTime(),
            .invalid
        ) else {
            throw "Failed to create sample buffer"
        }
        return sampleBuffer
    }

    private func handleAudio(_ senderFd: Int32, _ header: SampleBufferHeader) throws -> CMSampleBuffer? {
        _ = try read(senderFd, header.bufferSize)
        return nil
    }

    private func readHeader(_ senderFd: Int32) throws -> SampleBufferHeader {
        let sizeData = try read(senderFd, 4)
        let size = Int(sizeData.getUInt32Be())
        let data = try read(senderFd, size)
        return try PropertyListDecoder().decode(SampleBufferHeader.self, from: data)
    }

    private func read(_ senderFd: Int32, _ count: Int) throws -> Data {
        var data = Data(count: count)
        try data.withUnsafeMutableBytes { (pointer: UnsafeMutableRawBufferPointer) in
            try readPointer(senderFd, pointer.baseAddress!, count)
        }
        return data
    }

    private func readPointer(_ senderFd: Int32, _ pointer: UnsafeMutableRawPointer, _ count: Int) throws {
        var offset = 0
        while offset < count {
            let readCount = Darwin.read(senderFd, pointer.advanced(by: offset), count - offset)
            if readCount <= 0 {
                throw "Closed"
            }
            offset += readCount
        }
    }

    private func getVideoBufferPool(_ header: SampleBufferHeader) throws -> CVPixelBufferPool {
        if let videoBufferPool {
            return videoBufferPool
        }
        let pixelBufferAttributes: [NSString: AnyObject] = [
            kCVPixelBufferPixelFormatTypeKey: NSNumber(value: header.mediaSubType),
            kCVPixelBufferIOSurfacePropertiesKey: NSDictionary(),
            kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferWidthKey: NSNumber(value: header.width),
            kCVPixelBufferHeightKey: NSNumber(value: header.height),
        ]
        CVPixelBufferPoolCreate(
            nil,
            nil,
            pixelBufferAttributes as NSDictionary?,
            &videoBufferPool
        )
        guard let videoBufferPool else {
            throw "Failed to create pool"
        }
        return videoBufferPool
    }
}

private func createPixelBuffer(pool: CVPixelBufferPool) throws -> CVPixelBuffer {
    var outputImageBuffer: CVPixelBuffer?
    guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &outputImageBuffer) ==
        kCVReturnSuccess, let outputImageBuffer
    else {
        throw "Failed to create pixel buffer"
    }
    return outputImageBuffer
}
