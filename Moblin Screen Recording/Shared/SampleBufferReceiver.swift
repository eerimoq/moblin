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
            let header = try readHeader(senderFd: senderFd)
            let data = try read(senderFd: senderFd, count: header.bufferSize)
            guard let type = RPSampleBufferType(rawValue: header.bufferType) else {
                break
            }
            let sampleBuffer: CMSampleBuffer?
            switch type {
            case .video:
                sampleBuffer = try handleVideo(header, data)
            case .audioApp:
                sampleBuffer = handleAudio(header, data)
            default:
                continue
            }
            guard let sampleBuffer else {
                continue
            }
            delegate?.handleSampleBuffer(type: type, sampleBuffer: sampleBuffer)
        }
    }

    private func handleVideo(_ header: SampleBufferHeader, _: Data) throws -> CMSampleBuffer? {
        let pixelBufferPool = try getVideoBufferPool(header)
        let pixelBuffer = try createPixelBuffer(pool: pixelBufferPool)
        guard let formatDescription = CMVideoFormatDescription.create(imageBuffer: pixelBuffer)
        else {
            throw "Failed to create format description"
        }
        return CMSampleBuffer.create(
            pixelBuffer,
            formatDescription,
            .invalid,
            header.presentationTimeStamp.toCMTime(),
            .invalid
        )
    }

    private func handleAudio(_: SampleBufferHeader, _: Data) -> CMSampleBuffer? {
        return nil
    }

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
