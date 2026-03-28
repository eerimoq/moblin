import AVFoundation

struct RecorderDataSegment {
    let data: Data
    let startTime: Double
    let duration: Double
}

protocol RecorderDelegate: AnyObject {
    func recorderInitSegment(data: Data)
    func recorderDataSegment(segment: RecorderDataSegment)
    func recorderFinished()
}

private let fileWriterQueue = DispatchQueue(label: "com.eerimoq.recorder")

class Recorder: NSObject {
    private var replay = false
    private var audioOutputSettings: [String: Any] = [:]
    private var videoOutputSettings: [String: Any] = [:]
    private var fileHandle: FileHandle?
    private var initSegment: Data?
    private var outputChannelsMap: [Int: Int] = [0: 0, 1: 1]
    private var writer: AVAssetWriter?
    private var audioWriterInput: AVAssetWriterInput?
    private var videoWriterInput: AVAssetWriterInput?
    private var audioConverter: AVAudioConverter?
    private var audioRingBuffer: AudioEncoderRingBuffer?
    private var aacFormatDescription: CMFormatDescription?
    private var basePresentationTimeStamp: CMTime = .zero
    weak var delegate: RecorderDelegate?

    func setAudioChannelsMap(map: [Int: Int]) {
        processorPipelineQueue.async {
            self.outputChannelsMap = map
        }
    }

    func startRunning(
        url: URL?,
        replay: Bool,
        audioOutputSettings: [String: Any],
        videoOutputSettings: [String: Any]
    ) {
        processorPipelineQueue.async {
            self.startRunningInternal(
                url: url,
                replay: replay,
                audioOutputSettings: audioOutputSettings,
                videoOutputSettings: videoOutputSettings
            )
        }
    }

    func stopRunning() {
        processorPipelineQueue.async {
            self.stopRunningInternal()
        }
    }

    func setUrl(url: URL?) {
        fileWriterQueue.async {
            if let url {
                try? Data().write(to: url)
                self.fileHandle = FileHandle(forWritingAtPath: url.path)
                if let initSegment = self.initSegment {
                    self.fileHandle?.write(initSegment)
                }
            } else {
                self.fileHandle = nil
            }
        }
    }

    func setReplayBuffering(enabled: Bool) {
        fileWriterQueue.async {
            self.replay = enabled
            if let initSegment = self.initSegment {
                self.delegate?.recorderInitSegment(data: initSegment)
            }
        }
    }

    func appendAudio(_ sampleBuffer: CMSampleBuffer, _ presentationTimeStamp: CMTime) {
        guard writer != nil else {
            return
        }
        setupAudioEncoderIfNeeded(sampleBuffer)
        guard let audioConverter, let audioRingBuffer else {
            return
        }
        try? sampleBuffer.withAudioBufferList { audioBufferList, _ in
            audioRingBuffer.setWorkingSampleBuffer(audioBufferList, presentationTimeStamp)
            while let (outputBuffer, bufferPTS) = audioRingBuffer.createOutputBuffer() {
                encodeAndAppendAudioBuffer(audioConverter, outputBuffer, bufferPTS)
            }
        }
    }

    func appendVideo(_ sampleBuffer: CMSampleBuffer) {
        guard let writer,
              let input = getVideoWriterInput(sampleBuffer: sampleBuffer),
              isReadyForStartWriting(writer: writer),
              input.isReadyForMoreMediaData,
              let sampleBuffer = sampleBuffer
              .replacePresentationTimeStamp(sampleBuffer.presentationTimeStamp - basePresentationTimeStamp)
        else {
            return
        }
        if !input.append(sampleBuffer) {
            logger.info("""
            recorder: video: Append failed with \(writer.error?.localizedDescription ?? "") \
            (status: \(writer.status))
            """)
            stopRunningInternal()
        }
    }

    private func encodeAndAppendAudioBuffer(
        _ audioConverter: AVAudioConverter,
        _ inputBuffer: AVAudioPCMBuffer,
        _ presentationTimeStamp: CMTime
    ) {
        let outputBuffer = AVAudioCompressedBuffer(
            format: audioConverter.outputFormat,
            packetCapacity: 1,
            maximumPacketSize: 1024 * Int(audioConverter.outputFormat.channelCount)
        )
        var error: NSError?
        audioConverter.convert(to: outputBuffer, error: &error) { _, status in
            status.pointee = .haveData
            return inputBuffer
        }
        if let error {
            logger.info("recorder: audio: AAC encode failed: \(error)")
            return
        }
        guard let sampleBuffer = makeCompressedSampleBuffer(outputBuffer, presentationTimeStamp) else {
            return
        }
        appendEncodedAudio(sampleBuffer, presentationTimeStamp)
    }

    private func makeCompressedSampleBuffer(
        _ compressedBuffer: AVAudioCompressedBuffer,
        _ presentationTimeStamp: CMTime
    ) -> CMSampleBuffer? {
        let dataLength = Int(compressedBuffer.byteLength)
        guard dataLength > 0 else {
            return nil
        }
        var blockBuffer: CMBlockBuffer?
        guard CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: nil,
            blockLength: dataLength,
            blockAllocator: kCFAllocatorDefault,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: dataLength,
            flags: 0,
            blockBufferOut: &blockBuffer
        ) == noErr, let blockBuffer else {
            return nil
        }
        guard CMBlockBufferReplaceDataBytes(
            with: compressedBuffer.data,
            blockBuffer: blockBuffer,
            offsetIntoDestination: 0,
            dataLength: dataLength
        ) == noErr else {
            return nil
        }
        var sampleSize = dataLength
        var timing = CMSampleTimingInfo(
            duration: CMTime(
                value: 1024,
                timescale: CMTimeScale(compressedBuffer.format.sampleRate)
            ),
            presentationTimeStamp: presentationTimeStamp,
            decodeTimeStamp: .invalid
        )
        var sampleBuffer: CMSampleBuffer?
        guard CMSampleBufferCreate(
            allocator: kCFAllocatorDefault,
            dataBuffer: blockBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: aacFormatDescription,
            sampleCount: 1,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleSizeEntryCount: 1,
            sampleSizeArray: &sampleSize,
            sampleBufferOut: &sampleBuffer
        ) == noErr else {
            return nil
        }
        return sampleBuffer
    }

    private func appendEncodedAudio(_ sampleBuffer: CMSampleBuffer, _ presentationTimeStamp: CMTime) {
        guard let writer,
              let input = getAudioWriterInput(sampleBuffer: sampleBuffer, presentationTimeStamp),
              isReadyForStartWriting(writer: writer),
              input.isReadyForMoreMediaData,
              let sampleBuffer = sampleBuffer
              .replacePresentationTimeStamp(presentationTimeStamp - basePresentationTimeStamp)
        else {
            return
        }
        if !input.append(sampleBuffer) {
            logger.info("""
            recorder: audio: Append failed with \(writer.error?.localizedDescription ?? "") \
            (status: \(writer.status))
            """)
            stopRunningInternal()
        }
    }

    private func createAudioWriterInput(sampleBuffer: CMSampleBuffer,
                                        _ presentationTimeStamp: CMTime) -> AVAssetWriterInput
    {
        return makeWriterInput(.audio, nil, sampleBuffer, presentationTimeStamp)
    }

    private func getAudioWriterInput(sampleBuffer: CMSampleBuffer,
                                     _ presentationTimeStamp: CMTime) -> AVAssetWriterInput?
    {
        if audioWriterInput == nil {
            audioWriterInput = createAudioWriterInput(sampleBuffer: sampleBuffer, presentationTimeStamp)
        }
        return audioWriterInput
    }

    private func createVideoWriterInput(sampleBuffer: CMSampleBuffer) -> AVAssetWriterInput? {
        guard let pixelBuffer = sampleBuffer.imageBuffer else {
            return nil
        }
        var outputSettings: [String: Any] = [:]
        for (key, value) in videoOutputSettings {
            switch key {
            case AVVideoHeightKey:
                outputSettings[key] = isZero(value) ? pixelBuffer.height : value
            case AVVideoWidthKey:
                outputSettings[key] = isZero(value) ? pixelBuffer.width : value
            default:
                outputSettings[key] = value
            }
        }
        return makeWriterInput(.video, outputSettings, sampleBuffer, sampleBuffer.presentationTimeStamp)
    }

    private func getVideoWriterInput(sampleBuffer: CMSampleBuffer) -> AVAssetWriterInput? {
        if videoWriterInput == nil {
            videoWriterInput = createVideoWriterInput(sampleBuffer: sampleBuffer)
        }
        return videoWriterInput
    }

    private func makeWriterInput(_ mediaType: AVMediaType,
                                 _ outputSettings: [String: Any]?,
                                 _ sampleBuffer: CMSampleBuffer,
                                 _ presentationTimeStamp: CMTime) -> AVAssetWriterInput
    {
        if let audioStreamBasicDescription = sampleBuffer.formatDescription?.audioStreamBasicDescription {
            logger.info("""
            recorder: Make writer: Output: \(String(describing: outputSettings)), \
            Input: \(audioStreamBasicDescription)
            """)
        }
        let input = AVAssetWriterInput(
            mediaType: mediaType,
            outputSettings: outputSettings,
            sourceFormatHint: sampleBuffer.formatDescription
        )
        input.expectsMediaDataInRealTime = true
        writer?.add(input)
        if writer?.inputs.count == 2 {
            writer?.startWriting()
            writer?.startSession(atSourceTime: .zero)
            basePresentationTimeStamp = presentationTimeStamp
        }
        return input
    }

    private func setupAudioEncoderIfNeeded(_ sampleBuffer: CMSampleBuffer) {
        guard audioConverter == nil else {
            return
        }
        guard var streamBasicDescription = sampleBuffer.formatDescription?.audioStreamBasicDescription else {
            return
        }
        logger.info("recorder: Setting up AAC encoder from \(streamBasicDescription)")
        guard let inputFormat = AudioEncoder.makeAudioFormat(&streamBasicDescription) else {
            return
        }
        let channels = min(inputFormat.channelCount, 2)
        var outputDescription = AudioStreamBasicDescription(
            mSampleRate: inputFormat.sampleRate,
            mFormatID: kAudioFormatMPEG4AAC,
            mFormatFlags: UInt32(MPEG4ObjectID.AAC_LC.rawValue),
            mBytesPerPacket: 0,
            mFramesPerPacket: 1024,
            mBytesPerFrame: 0,
            mChannelsPerFrame: channels,
            mBitsPerChannel: 0,
            mReserved: 0
        )
        guard let outputFormat = AVAudioFormat(streamDescription: &outputDescription) else {
            return
        }
        logger.info("recorder: AAC encoder input: \(inputFormat), output: \(outputFormat)")
        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            logger.info("recorder: Failed to create AAC converter")
            return
        }
        converter.channelMap = makeChannelMap(
            numberOfInputChannels: Int(inputFormat.channelCount),
            numberOfOutputChannels: Int(channels),
            outputToInputChannelsMap: outputChannelsMap
        )
        if let bitrate = audioOutputSettings[AVEncoderBitRateKey] as? Int, bitrate > 0 {
            converter.setBitrate(to: bitrate)
        }
        audioConverter = converter
        audioRingBuffer = AudioEncoderRingBuffer(&streamBasicDescription, numSamplesPerBuffer: 1024)
        var formatDescription: CMAudioFormatDescription?
        CMAudioFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            asbd: &outputDescription,
            layoutSize: 0,
            layout: nil,
            magicCookieSize: 0,
            magicCookie: nil,
            extensions: nil,
            formatDescriptionOut: &formatDescription
        )
        aacFormatDescription = formatDescription
    }

    private func startRunningInternal(
        url: URL?,
        replay: Bool,
        audioOutputSettings: [String: Any],
        videoOutputSettings: [String: Any]
    ) {
        self.replay = replay
        self.audioOutputSettings = audioOutputSettings
        self.videoOutputSettings = videoOutputSettings
        guard writer == nil else {
            logger.info("recorder: Will not start recording as it is already running or missing URL")
            return
        }
        reset()
        writer = AVAssetWriter(contentType: UTType(AVFileType.mp4.rawValue)!)
        writer?.shouldOptimizeForNetworkUse = true
        writer?.outputFileTypeProfile = .mpeg4AppleHLS
        writer?.preferredOutputSegmentInterval = CMTime(seconds: 2)
        writer?.delegate = self
        writer?.initialSegmentStartTime = .zero
        setUrl(url: url)
    }

    private func stopRunningInternal() {
        guard let writer else {
            logger.info("recorder: Will not stop recording as it is not running")
            return
        }
        guard writer.status == .writing else {
            logger.info("recorder: Failed to finish writing \(writer.error?.localizedDescription ?? "")")
            reset()
            return
        }
        writer.finishWriting {
            self.delegate?.recorderFinished()
        }
        reset()
    }

    private func reset() {
        writer = nil
        audioWriterInput = nil
        videoWriterInput = nil
        audioConverter = nil
        audioRingBuffer = nil
        aacFormatDescription = nil
        basePresentationTimeStamp = .zero
        fileWriterQueue.async {
            self.fileHandle = nil
            self.initSegment = nil
        }
    }

    private func isReadyForStartWriting(writer: AVAssetWriter) -> Bool {
        return writer.inputs.count == 2
    }
}

extension Recorder: AVAssetWriterDelegate {
    func assetWriter(_: AVAssetWriter,
                     didOutputSegmentData segmentData: Data,
                     segmentType: AVAssetSegmentType,
                     segmentReport: AVAssetSegmentReport?)
    {
        fileWriterQueue.async {
            self.fileHandle?.write(segmentData)
            if segmentType == .initialization {
                self.initSegment = segmentData
            }
            if self.replay {
                switch segmentType {
                case .initialization:
                    self.delegate?.recorderInitSegment(data: segmentData)
                case .separable:
                    if let report = segmentReport?.trackReports.first {
                        self.delegate?.recorderDataSegment(segment: RecorderDataSegment(
                            data: segmentData,
                            startTime: report.earliestPresentationTimeStamp.seconds,
                            duration: report.duration.seconds
                        ))
                    }
                default:
                    break
                }
            }
        }
    }
}
