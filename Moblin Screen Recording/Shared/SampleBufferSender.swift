import AVFoundation
import ReplayKit
import System
import VideoToolbox

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
    private var fd: FileDescriptor?
    private var videoEncoder: VideoEncoder?
    private var audioConverter: AVAudioConverter?
    private var appGroup: String?
    private let lock = NSLock()

    func start(appGroup: String) {
        self.appGroup = appGroup
    }

    func stop() {
        lock.withLock {
            try? fd?.close()
            fd = nil
        }
    }

    func send(_ sampleBuffer: CMSampleBuffer, _ type: RPSampleBufferType) {
        let connected = lock.withLock {
            isConnected() || tryConnect()
        }
        guard connected else {
            return
        }
        switch type {
        case .video:
            try? sendVideo(sampleBuffer, type)
        case .audioApp:
            sendAudio(sampleBuffer)
        default:
            break
        }
    }

    private func isConnected() -> Bool {
        fd != nil
    }

    private func tryConnect() -> Bool {
        guard let appGroup else {
            return false
        }
        do {
            let rawFd = try createSocket()
            fd = FileDescriptor(rawValue: rawFd)
            try setIgnoreSigPipe(fd: rawFd)
            let containerDir = try createContainerDir(appGroup: appGroup)
            let path = createSocketPath(containerDir: containerDir)
            let addr = try createAddr(path: path)
            try connect(fd: rawFd, addr: addr)
        } catch {
            try? fd?.close()
            fd = nil
            return false
        }
        return true
    }

    private func sendVideo(_ sampleBuffer: CMSampleBuffer, _: RPSampleBufferType) throws {
        guard let imageBuffer = sampleBuffer.imageBuffer else {
            return
        }
        if videoEncoder == nil, let dimensions = sampleBuffer.formatDescription?.dimensions {
            videoEncoder = VideoEncoder(width: dimensions.width, height: dimensions.height)
            videoEncoder?.delegate = self
        }
        videoEncoder?.appendImageBuffer(imageBuffer, sampleBuffer.presentationTimeStamp)
    }

    private func sendAudio(_ sampleBuffer: CMSampleBuffer) {
        guard let formatDescription = sampleBuffer.formatDescription else {
            return
        }
        let inputFormat = AVAudioFormat(cmAudioFormatDescription: formatDescription)
        let numberOfFrames = AVAudioFrameCount(sampleBuffer.numSamples)
        guard numberOfFrames > 0,
              let outputFormat = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                               sampleRate: inputFormat.sampleRate,
                                               channels: inputFormat.channelCount,
                                               interleaved: true),
              let inputBuffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: numberOfFrames),
              let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: numberOfFrames)
        else {
            return
        }
        inputBuffer.frameLength = numberOfFrames
        guard CMSampleBufferCopyPCMDataIntoAudioBufferList(
            sampleBuffer,
            at: 0,
            frameCount: Int32(numberOfFrames),
            into: inputBuffer.mutableAudioBufferList
        ) == noErr else {
            return
        }
        if audioConverter?.inputFormat != inputFormat {
            audioConverter = AVAudioConverter(from: inputFormat, to: outputFormat)
        }
        guard let audioConverter,
              (try? audioConverter.convert(to: outputBuffer, from: inputBuffer)) != nil,
              let data = outputBuffer.int16ChannelData
        else {
            return
        }
        let size = Int(outputBuffer.frameLength) * Int(outputFormat.channelCount) * MemoryLayout<Int16>.size
        let header = SampleBufferHeader(
            type: .audioBuffer,
            size: size,
            presentationTimeStamp: sampleBuffer.presentationTimeStamp.seconds,
            isSync: false,
            sampleRate: outputFormat.sampleRate,
            numberOfChannels: Int(outputFormat.channelCount)
        )
        try? sendMessage(header, UnsafeRawBufferPointer(start: UnsafeRawPointer(data[0]), count: size))
    }

    private func sendMessage(_ header: SampleBufferHeader, _ payload: UnsafeRawBufferPointer) throws {
        try lock.withLock {
            try sendHeader(header)
            try send(pointer: payload)
        }
    }

    private func sendHeader(_ header: SampleBufferHeader) throws {
        let data = try PropertyListEncoder().encode(header)
        var size = Data(count: 4)
        size.setUInt32Be(value: UInt32(data.count))
        try send(data: size)
        try send(data: data)
    }

    private func send(data: Data) throws {
        _ = try fd?.writeAll(data)
    }

    private func send(pointer: UnsafeRawBufferPointer) throws {
        _ = try fd?.writeAll(pointer)
    }
}

extension SampleBufferSender: VideoEncoderDelegate {
    func videoEncoderOutputFormat(_ formatDescription: CMFormatDescription) {
        guard let atoms = formatDescription.atoms() else {
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
        try? hvcC.withUnsafeBytes {
            try sendMessage(header, $0)
        }
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
            isSync: sampleBuffer.getIsSync()
        )
        try? sendMessage(header, UnsafeRawBufferPointer(start: UnsafeRawPointer(buffer), count: size))
    }
}

protocol VideoEncoderDelegate: AnyObject {
    func videoEncoderOutputFormat(_ formatDescription: CMFormatDescription)
    func videoEncoderOutputSampleBuffer(_ sampleBuffer: CMSampleBuffer)
}

class VideoEncoder: @unchecked Sendable {
    weak var delegate: (any VideoEncoderDelegate)?
    private var session: VTCompressionSession?
    private var formatDescription: CMFormatDescription? {
        didSet {
            guard !CMFormatDescriptionEqual(formatDescription, otherFormatDescription: oldValue) else {
                return
            }
            guard let formatDescription else {
                return
            }
            delegate?.videoEncoderOutputFormat(formatDescription)
        }
    }

    init(width: Int32, height: Int32) {
        session = makeCompressionSession(width: width, height: height)
    }

    func appendImageBuffer(_ imageBuffer: CVImageBuffer, _ presentationTimeStamp: CMTime) {
        guard let session else {
            return
        }
        _ = VTCompressionSessionEncodeFrame(
            session,
            imageBuffer: imageBuffer,
            presentationTimeStamp: presentationTimeStamp,
            duration: .invalid,
            frameProperties: nil,
            infoFlagsOut: nil,
            outputHandler: { [weak self] status, _, sampleBuffer in
                guard let self else {
                    return
                }
                guard let sampleBuffer, status == noErr else {
                    return
                }
                formatDescription = sampleBuffer.formatDescription
                delegate?.videoEncoderOutputSampleBuffer(sampleBuffer)
            }
        )
    }
}

private func makeCompressionSession(width: Int32, height: Int32) -> VTCompressionSession? {
    var session: VTCompressionSession?
    let attributes: [NSString: AnyObject] = [
        kCVPixelBufferPixelFormatTypeKey: NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange),
        kCVPixelBufferWidthKey: NSNumber(value: width),
        kCVPixelBufferHeightKey: NSNumber(value: height),
    ]
    var status = VTCompressionSessionCreate(
        allocator: kCFAllocatorDefault,
        width: width,
        height: height,
        codecType: kCMVideoCodecType_HEVC,
        encoderSpecification: nil,
        imageBufferAttributes: attributes as CFDictionary?,
        compressedDataAllocator: nil,
        outputCallback: nil,
        refcon: nil,
        compressionSessionOut: &session
    )
    guard status == noErr, let session else {
        return nil
    }
    let options: [NSString: AnyObject] = [
        kVTCompressionPropertyKey_RealTime: kCFBooleanTrue,
        kVTCompressionPropertyKey_ProfileLevel: kVTProfileLevel_HEVC_Main_AutoLevel as NSObject,
        kVTCompressionPropertyKey_AverageBitRate: 10_000_000 as CFNumber,
        kVTCompressionPropertyKey_ExpectedFrameRate: 30 as CFNumber,
        kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration: 2 as NSNumber,
        kVTCompressionPropertyKey_AllowFrameReordering: kCFBooleanFalse,
        kVTCompressionPropertyKey_PixelTransferProperties: ["ScalingMode": "Trim"] as NSObject,
    ]
    status = VTSessionSetProperties(session, propertyDictionary: options as CFDictionary)
    guard status == noErr else {
        return nil
    }
    status = VTCompressionSessionPrepareToEncodeFrames(session)
    guard status == noErr else {
        return nil
    }
    return session
}
