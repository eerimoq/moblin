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

private var lockQueue = DispatchQueue(label: "com.eerimoq.Moblin.SampleBufferReceiver")

class SampleBufferReceiver {
    private var listenerFd: Int32
    weak var delegate: (any SampleBufferReceiverDelegate)?
    private var formatDescription: CMVideoFormatDescription?
    private var videoDecoder: VideoCodec?

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
        while true {
            let header = try readHeader(senderFd)
            switch header.type {
            case .videoFormat:
                try handleVideoFormat(senderFd, header)
            case .videoBuffer:
                try handleVideoBuffer(senderFd, header)
            }
        }
    }

    private func handleVideoFormat(_ senderFd: Int32, _ header: SampleBufferHeader) throws {
        let hvcC = try read(senderFd, header.size)
        let config = MpegTsVideoConfigHevc(data: hvcC)
        let status = config.makeFormatDescription(&formatDescription)
        if status == noErr, let formatDescription {
            videoDecoder = VideoCodec(lockQueue: lockQueue)
            videoDecoder!.formatDescription = formatDescription
            videoDecoder!.delegate = self
            videoDecoder!.startRunning()
        }
    }

    private func handleVideoBuffer(_ senderFd: Int32, _ header: SampleBufferHeader) throws {
        let data = try read(senderFd, header.size)
        let timestamp = CMTime(seconds: header.presentationTimeStamp + 0.2, preferredTimescale: 1000)
        var timing = CMSampleTimingInfo(
            duration: CMTimeMake(value: 30, timescale: 1000),
            presentationTimeStamp: timestamp,
            decodeTimeStamp: timestamp
        )
        let blockBuffer = data.makeBlockBuffer()
        var sampleBuffer: CMSampleBuffer?
        var sampleSize = blockBuffer?.dataLength ?? 0
        guard CMSampleBufferCreate(
            allocator: kCFAllocatorDefault,
            dataBuffer: blockBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: formatDescription,
            sampleCount: 1,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleSizeEntryCount: 1,
            sampleSizeArray: &sampleSize,
            sampleBufferOut: &sampleBuffer
        ) == noErr, let sampleBuffer else {
            return
        }
        sampleBuffer.isSync = header.isSync
        videoDecoder?.appendSampleBuffer(sampleBuffer)
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
}

extension SampleBufferReceiver: VideoCodecDelegate {
    func videoCodecOutputFormat(_: VideoCodec, _: CMFormatDescription) {}

    func videoCodecOutputSampleBuffer(_: VideoCodec, _ sampleBuffer: CMSampleBuffer) {
        delegate?.handleSampleBuffer(type: .video, sampleBuffer: sampleBuffer)
    }
}
