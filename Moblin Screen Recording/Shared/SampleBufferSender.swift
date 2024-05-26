import AVFoundation
import ReplayKit

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

class SampleBufferSender {
    private var fd: Int32

    init() {
        fd = -1
    }

    func start(appGroup: String) {
        do {
            fd = try createSocket()
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
        let header = SampleBufferHeader(bufferType: type.rawValue,
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
        let header = SampleBufferHeader(
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

    private func sendHeader(_ header: SampleBufferHeader) throws {
        let data = try PropertyListEncoder().encode(header)
        var size = Data(count: 4)
        size.setUInt32Be(value: UInt32(data.count))
        try send(data: size)
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
