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

class SampleBufferSender: NSObject {
    private var fd: Int32
    private var videoEncoder: VideoEncoder?

    override init() {
        fd = -1
        super.init()
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

    private func sendVideo(_ sampleBuffer: CMSampleBuffer, _: RPSampleBufferType) throws {
        guard let imageBuffer = sampleBuffer.imageBuffer else {
            return
        }
        if videoEncoder == nil, let formatDescription = sampleBuffer.formatDescription {
            videoEncoder = VideoEncoder(
                width: formatDescription.dimensions.width,
                height: formatDescription.dimensions.height
            )
            videoEncoder?.delegate = self
        }
        videoEncoder?.appendImageBuffer(
            imageBuffer,
            presentationTimeStamp: sampleBuffer.presentationTimeStamp,
            duration: sampleBuffer.duration
        )
    }

    private func sendAudio(_: CMSampleBuffer, _: RPSampleBufferType) throws {}

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

extension SampleBufferSender: VideoEncoderDelegate {
    func videoEncoderOutputFormat(_ formatDescription: CMFormatDescription) {
        guard let atoms = CMFormatDescriptionGetExtension(
            formatDescription,
            extensionKey: "SampleDescriptionExtensionAtoms" as CFString
        ) as? NSDictionary else {
            return
        }
        guard let hvcC = atoms["hvcC"] as? Data else {
            return
        }
        let header = SampleBufferHeader(
            type: .videoFormat,
            size: hvcC.count,
            presentationTimeStamp: 0.0,
            isSync: false
        )
        do {
            try sendHeader(header)
            try send(data: hvcC)
        } catch {}
    }

    func videoEncoderOutputSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard let dataBuffer = sampleBuffer.dataBuffer else {
            return
        }
        guard let (buffer, size) = dataBuffer.getDataPointer() else {
            return
        }
        let header = SampleBufferHeader(
            type: .videoBuffer,
            size: size,
            presentationTimeStamp: sampleBuffer.presentationTimeStamp.seconds,
            isSync: sampleBuffer.isSync
        )
        do {
            try sendHeader(header)
            try send(pointer: UnsafeRawBufferPointer(start: UnsafeRawPointer(buffer), count: size))
        } catch {}
    }
}
