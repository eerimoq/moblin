import AVFoundation
import CoreAudio
import ReplayKit
import System

let screenRecordingLatency = 0.2

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

private let lockQueue = DispatchQueue(label: "com.eerimoq.Moblin.SampleBufferReceiver")

class SampleBufferReceiver: @unchecked Sendable {
    private var listenerFd: Int32 = -1
    weak var delegate: (any SampleBufferReceiverDelegate)?
    private var formatDescription: CMVideoFormatDescription?
    private var videoDecoder: VideoDecoder?
    private var audioConverter: AVAudioConverter?
    private let colorRange: Atomic<SettingsStreamColorRange> = .init(.full)

    func setPixelFormatType(_ colorRange: SettingsStreamColorRange) {
        self.colorRange.mutate { $0 = colorRange }
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
            let senderFd = try FileDescriptor(rawValue: accept(fd: listenerFd))
            try setIgnoreSigPipe(fd: senderFd.rawValue)
            delegate?.senderConnected()
            try? senderFd.closeAfter {
                try readLoop(senderFd: senderFd)
            }
            delegate?.senderDisconnected()
        }
    }

    private func readLoop(senderFd: FileDescriptor) throws {
        while true {
            let header = try readHeader(senderFd)
            switch header.type {
            case .videoFormat:
                try handleVideoFormat(senderFd, header)
            case .videoBuffer:
                try handleVideoBuffer(senderFd, header)
            case .audioFormat:
                try handleAudioFormat(senderFd, header)
            case .audioBuffer:
                try handleAudioBuffer(senderFd, header)
            }
        }
    }

    private func handleVideoFormat(_ senderFd: FileDescriptor, _ header: SampleBufferHeader) throws {
        let hvcC = try read(senderFd, header.size)
        let config = MpegTsVideoConfigHevc(hvcC: hvcC)
        let status = config.makeFormatDescription(&formatDescription)
        if status == noErr, let formatDescription {
            videoDecoder = VideoDecoder(name: "",
                                        lockQueue: lockQueue,
                                        softwareDecoding: false,
                                        colorRange: colorRange.value)
            videoDecoder!.delegate = self
            videoDecoder!.startRunning(formatDescription: formatDescription)
        }
    }

    private func handleVideoBuffer(_ senderFd: FileDescriptor, _ header: SampleBufferHeader) throws {
        let data = try read(senderFd, header.size)
        let timestamp = CMTime(seconds: header.presentationTimeStamp + screenRecordingLatency)
        var timing = CMSampleTimingInfo(
            duration: .invalid,
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
        sampleBuffer.setIsSync(header.isSync)
        videoDecoder?.decodeSampleBuffer(sampleBuffer)
    }

    private func handleAudioFormat(_ senderFd: FileDescriptor, _ header: SampleBufferHeader) throws {
        let data = try read(senderFd, header.size)
        audioConverter = nil
        guard data.count == MemoryLayout<AudioStreamBasicDescription>.size else {
            return
        }
        var asbd = data.withUnsafeBytes { $0.loadUnaligned(as: AudioStreamBasicDescription.self) }
        guard let inputFormat = AVAudioFormat(streamDescription: &asbd),
              let outputFormat = AVAudioFormat(
                  commonFormat: .pcmFormatInt16,
                  sampleRate: inputFormat.sampleRate,
                  channels: inputFormat.channelCount,
                  interleaved: true
              )
        else {
            return
        }
        audioConverter = AVAudioConverter(from: inputFormat, to: outputFormat)
    }

    private func handleAudioBuffer(_ senderFd: FileDescriptor, _ header: SampleBufferHeader) throws {
        let data = try read(senderFd, header.size)
        guard let audioConverter else {
            return
        }
        let inputFormat = audioConverter.inputFormat
        let bytesPerFrame = Int(inputFormat.streamDescription.pointee.mBytesPerFrame)
        let numberOfBuffers = inputFormat.isInterleaved ? 1 : Int(inputFormat.channelCount)
        guard bytesPerFrame > 0 else {
            return
        }
        let frameCount = AVAudioFrameCount(data.count / bytesPerFrame / numberOfBuffers)
        guard frameCount > 0,
              let inputBuffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: frameCount),
              let outputBuffer = AVAudioPCMBuffer(
                  pcmFormat: audioConverter.outputFormat,
                  frameCapacity: frameCount
              )
        else {
            return
        }
        inputBuffer.frameLength = frameCount
        let bufferSize = Int(frameCount) * bytesPerFrame
        let buffers = UnsafeMutableAudioBufferListPointer(inputBuffer.mutableAudioBufferList)
        data.withUnsafeBytes { pointer in
            for (index, buffer) in buffers.enumerated() {
                buffer.mData?.copyMemory(from: pointer.baseAddress! + index * bufferSize,
                                         byteCount: bufferSize)
            }
        }
        do {
            try audioConverter.convert(to: outputBuffer, from: inputBuffer)
        } catch {
            return
        }
        let timestamp = CMTime(seconds: header.presentationTimeStamp + screenRecordingLatency)
        guard let sampleBuffer = outputBuffer.makeSampleBuffer(timestamp) else {
            return
        }
        delegate?.handleSampleBuffer(type: .audioApp, sampleBuffer: sampleBuffer)
    }

    private func readHeader(_ senderFd: FileDescriptor) throws -> SampleBufferHeader {
        let sizeData = try read(senderFd, 4)
        let size = Int(sizeData.getUInt32Be())
        let data = try read(senderFd, size)
        return try PropertyListDecoder().decode(SampleBufferHeader.self, from: data)
    }

    private func read(_ senderFd: FileDescriptor, _ count: Int) throws -> Data {
        var data = Data(count: count)
        try data.withUnsafeMutableBytes { pointer in
            var offset = 0
            while offset < count {
                let readCount = try senderFd.read(into: .init(rebasing: pointer[offset...]))
                if readCount == 0 {
                    throw "Closed"
                }
                offset += readCount
            }
        }
        return data
    }
}

extension SampleBufferReceiver: VideoDecoderDelegate {
    func videoDecoderOutputSampleBuffer(_: VideoDecoder, _ sampleBuffer: CMSampleBuffer) {
        delegate?.handleSampleBuffer(type: .video, sampleBuffer: sampleBuffer)
    }
}
