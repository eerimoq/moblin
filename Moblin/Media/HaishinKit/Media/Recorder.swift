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

private class File: NSObject {
    private var fileHandle: FileHandle?
    private var initSegment: Data?
    private var writer: AVAssetWriter?
    private var audioWriterInput: AVAssetWriterInput?
    private var videoWriterInput: AVAssetWriterInput?
    private var audioConverter: AVAudioConverter?
    private var audioOutputFormat: AVAudioFormat?
    private var basePresentationTimeStamp: CMTime = .zero
    private(set) var maximumPresentationTimeStamp: CMTime = .negativeInfinity
    private(set) var replay = false
    weak var recorder: Recorder?
    private(set) var number: Int = 0

    func setUrl(baseUrl: URL?, number: Int) {
        self.number = number
        fileWriterQueue.async {
            if let baseUrl {
                let fileUrl = baseUrl.appendingPathComponent(String(format: "%04d.mp4", number))
                try? Data().write(to: fileUrl)
                self.fileHandle = FileHandle(forWritingAtPath: fileUrl.path)
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
                self.recorder?.delegate?.recorderInitSegment(data: initSegment)
            }
        }
    }

    func start(baseUrl: URL?, number: Int, replay: Bool) {
        self.number = number
        self.replay = replay
        guard writer == nil else {
            logger.info("recorder: Will not start recording as it is already running or missing URL")
            return
        }
        reset()
        writer = AVAssetWriter(contentType: .mpeg4Movie)
        writer?.shouldOptimizeForNetworkUse = true
        writer?.outputFileTypeProfile = .mpeg4AppleHLS
        writer?.preferredOutputSegmentInterval = CMTime(seconds: 2)
        writer?.delegate = self
        writer?.initialSegmentStartTime = .zero
        setUrl(baseUrl: baseUrl, number: number)
    }

    func stop() {
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
            self.recorder?.delegate?.recorderFinished()
        }
        reset()
    }

    func appendAudio(_ sampleBuffer: CMSampleBuffer, _ presentationTimeStamp: CMTime) {
        guard let writer,
              let sampleBuffer = convertAudio(sampleBuffer, presentationTimeStamp),
              let input = getAudioWriterInput(sampleBuffer: sampleBuffer, presentationTimeStamp),
              isReadyForStartWriting(writer: writer),
              input.isReadyForMoreMediaData,
              let sampleBuffer = sampleBuffer
              .replacePresentationTimeStamp(presentationTimeStamp - basePresentationTimeStamp)
        else {
            return
        }
        maximumPresentationTimeStamp = max(maximumPresentationTimeStamp, presentationTimeStamp)
        if !input.append(sampleBuffer) {
            logger.info("""
            recorder: audio: Append failed with \(writer.error?.localizedDescription ?? "") \
            (status: \(writer.status))
            """)
            stop()
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
        maximumPresentationTimeStamp = max(maximumPresentationTimeStamp, sampleBuffer.presentationTimeStamp)
        if !input.append(sampleBuffer) {
            logger.info("""
            recorder: video: Append failed with \(writer.error?.localizedDescription ?? "") \
            (status: \(writer.status))
            """)
            stop()
        }
    }

    private func convertAudio(_ sampleBuffer: CMSampleBuffer,
                              _ presentationTimeStamp: CMTime) -> CMSampleBuffer?
    {
        return tryConvertAudio(sampleBuffer, presentationTimeStamp, makeConverter: false)
            ?? tryConvertAudio(sampleBuffer, presentationTimeStamp, makeConverter: true)
    }

    private func tryConvertAudio(_ sampleBuffer: CMSampleBuffer,
                                 _ presentationTimeStamp: CMTime,
                                 makeConverter: Bool) -> CMSampleBuffer?
    {
        if makeConverter {
            makeAudioConverter(sampleBuffer.formatDescription)
        }
        guard let converter = audioConverter else {
            return nil
        }
        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: converter.outputFormat,
            frameCapacity: UInt32(sampleBuffer.numSamples)
        ) else {
            return nil
        }
        return try? sampleBuffer.withAudioBufferList { list, _ in
            guard let inputBuffer = AVAudioPCMBuffer(
                pcmFormat: converter.inputFormat,
                bufferListNoCopy: list.unsafePointer
            ) else {
                logger.info("recorder: Failed to create input buffer")
                return nil
            }
            do {
                try converter.convert(to: outputBuffer, from: inputBuffer)
            } catch {
                logger.info("recorder: audio: Convert failed with \(error.localizedDescription)")
                return nil
            }
            return outputBuffer.makeSampleBuffer(presentationTimeStamp)
        }
    }

    private func createAudioWriterInput(sampleBuffer: CMSampleBuffer,
                                        _ presentationTimeStamp: CMTime) -> AVAssetWriterInput?
    {
        guard let recorder else {
            return nil
        }
        let sourceFormatHint = sampleBuffer.formatDescription
        var outputSettings: [String: Any] = [:]
        if let sourceFormatHint, let inSourceFormat = sourceFormatHint.audioStreamBasicDescription {
            for (key, value) in recorder.audioOutputSettings {
                switch key {
                case AVSampleRateKey:
                    outputSettings[key] = isZero(value) ? inSourceFormat.mSampleRate : value
                case AVNumberOfChannelsKey:
                    outputSettings[key] = isZero(value) ? min(Int(inSourceFormat.mChannelsPerFrame), 2) :
                        value
                default:
                    outputSettings[key] = value
                }
            }
        }
        return makeWriterInput(.audio, outputSettings, sampleBuffer, presentationTimeStamp)
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
        guard let pixelBuffer = sampleBuffer.imageBuffer, let recorder else {
            return nil
        }
        var outputSettings: [String: Any] = [:]
        for (key, value) in recorder.videoOutputSettings {
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
                                 _ outputSettings: [String: Any],
                                 _ sampleBuffer: CMSampleBuffer,
                                 _ presentationTimeStamp: CMTime) -> AVAssetWriterInput
    {
        if let audioStreamBasicDescription = sampleBuffer.formatDescription?.audioStreamBasicDescription {
            logger.debug("""
            recorder: Make writer: Output: \(outputSettings), Input: \(audioStreamBasicDescription)
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

    private func makeAudioConverter(_ formatDescription: CMFormatDescription?) {
        guard var streamBasicDescription = formatDescription?.audioStreamBasicDescription else {
            return
        }
        logger.debug("recorder: Creating converter from \(streamBasicDescription)")
        guard let inputFormat = makeAudioFormat(&streamBasicDescription) else {
            return
        }
        if audioOutputFormat == nil {
            audioOutputFormat = AVAudioFormat(
                commonFormat: inputFormat.commonFormat,
                sampleRate: inputFormat.sampleRate,
                channels: min(inputFormat.channelCount, 2),
                interleaved: inputFormat.isInterleaved
            )
        }
        guard let audioOutputFormat, let recorder else {
            return
        }
        logger.debug("recorder: Input: \(inputFormat), output: \(audioOutputFormat)")
        audioConverter = AVAudioConverter(from: inputFormat, to: audioOutputFormat)
        audioConverter?.channelMap = makeChannelMap(
            numberOfInputChannels: Int(inputFormat.channelCount),
            numberOfOutputChannels: Int(audioOutputFormat.channelCount),
            outputToInputChannelsMap: recorder.outputChannelsMap
        )
    }

    private func makeChannelLayout(_ numberOfChannels: UInt32) -> AVAudioChannelLayout? {
        guard numberOfChannels > 2 else {
            return nil
        }
        return AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_DiscreteInOrder | numberOfChannels)
    }

    private func makeAudioFormat(_ basicDescription: inout AudioStreamBasicDescription) -> AVAudioFormat? {
        if basicDescription.mFormatID == kAudioFormatLinearPCM,
           kLinearPCMFormatFlagIsBigEndian ==
           (basicDescription.mFormatFlags & kLinearPCMFormatFlagIsBigEndian)
        {
            // ReplayKit audioApp.
            guard basicDescription.mBitsPerChannel == 16 else {
                return nil
            }
            if let layout = makeChannelLayout(basicDescription.mChannelsPerFrame) {
                return AVAudioFormat(
                    commonFormat: .pcmFormatInt16,
                    sampleRate: basicDescription.mSampleRate,
                    interleaved: true,
                    channelLayout: layout
                )
            }
            return AVAudioFormat(
                commonFormat: .pcmFormatInt16,
                sampleRate: basicDescription.mSampleRate,
                channels: basicDescription.mChannelsPerFrame,
                interleaved: true
            )
        }
        if let layout = makeChannelLayout(basicDescription.mChannelsPerFrame) {
            return AVAudioFormat(streamDescription: &basicDescription, channelLayout: layout)
        }
        return AVAudioFormat(streamDescription: &basicDescription)
    }

    private func reset() {
        writer = nil
        audioWriterInput = nil
        videoWriterInput = nil
        audioConverter = nil
        audioOutputFormat = nil
        basePresentationTimeStamp = .zero
        maximumPresentationTimeStamp = .negativeInfinity
        fileWriterQueue.async {
            self.fileHandle = nil
            self.initSegment = nil
        }
    }

    private func isReadyForStartWriting(writer: AVAssetWriter) -> Bool {
        return writer.inputs.count == 2
    }
}

extension File: AVAssetWriterDelegate {
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
                    self.recorder?.delegate?.recorderInitSegment(data: segmentData)
                case .separable:
                    if let report = segmentReport?.trackReports.first {
                        self.recorder?.delegate?.recorderDataSegment(segment: RecorderDataSegment(
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

class Recorder: NSObject {
    fileprivate var outputChannelsMap: [Int: Int] = [0: 0, 1: 1]
    fileprivate var audioOutputSettings: [String: Any] = [:]
    fileprivate var videoOutputSettings: [String: Any] = [:]
    weak var delegate: RecorderDelegate?
    private var currentFile = File()
    private var nextFile: File?
    private var rotating: Bool = false
    private var nextRotationPresentationTimeStamp: CMTime = .invalid
    private var maximumCurrentPresentationTimeStamp: CMTime = .invalid
    private var audioRotated: Bool = false
    private var videoRotated: Bool = false
    private var baseUrl: URL?

    override init() {
        super.init()
        currentFile.recorder = self
        createNextFile()
    }

    func start(
        baseUrl: URL?,
        replay: Bool,
        audioOutputSettings: [String: Any],
        videoOutputSettings: [String: Any]
    ) {
        self.baseUrl = baseUrl
        self.audioOutputSettings = audioOutputSettings
        self.videoOutputSettings = videoOutputSettings
        setNextRotationPresentationTimeStamp()
        currentFile.start(baseUrl: baseUrl, number: 1, replay: replay)
    }

    func stop() {
        currentFile.stop()
    }

    func setAudioChannelsMap(map: [Int: Int]) {
        outputChannelsMap = map
    }

    func setUrl(baseUrl: URL?) {
        self.baseUrl = baseUrl
        setNextRotationPresentationTimeStamp()
        currentFile.setUrl(baseUrl: baseUrl, number: 1)
    }

    func setReplay(enabled: Bool) {
        currentFile.setReplayBuffering(enabled: enabled)
    }

    func appendAudio(_ sampleBuffer: CMSampleBuffer, _ presentationTimeStamp: CMTime) {
        if rotating {
            appendAudioRotating(sampleBuffer, presentationTimeStamp)
        } else {
            appendAudioNotRotating(sampleBuffer, presentationTimeStamp)
        }
    }

    func appendVideo(_ sampleBuffer: CMSampleBuffer) {
        if rotating {
            appendVideoRotating(sampleBuffer)
        } else {
            appendVideoNotRotating(sampleBuffer)
        }
    }

    private func appendAudioRotating(_ sampleBuffer: CMSampleBuffer, _ presentationTimeStamp: CMTime) {
        if presentationTimeStamp < maximumCurrentPresentationTimeStamp {
            currentFile.appendAudio(sampleBuffer, presentationTimeStamp)
        } else {
            nextFile?.appendAudio(sampleBuffer, presentationTimeStamp)
            audioRotated = true
        }
        stopRotationIfNeeded()
    }

    private func appendVideoRotating(_ sampleBuffer: CMSampleBuffer) {
        if sampleBuffer.presentationTimeStamp < maximumCurrentPresentationTimeStamp {
            currentFile.appendVideo(sampleBuffer)
        } else {
            nextFile?.appendVideo(sampleBuffer)
            videoRotated = true
        }
        stopRotationIfNeeded()
    }

    private func appendAudioNotRotating(_ sampleBuffer: CMSampleBuffer, _ presentationTimeStamp: CMTime) {
        currentFile.appendAudio(sampleBuffer, presentationTimeStamp)
        startRotationIfNeeded(presentationTimeStamp)
    }

    private func appendVideoNotRotating(_ sampleBuffer: CMSampleBuffer) {
        currentFile.appendVideo(sampleBuffer)
        startRotationIfNeeded(sampleBuffer.presentationTimeStamp)
    }

    private func startRotationIfNeeded(_ presentationTimeStamp: CMTime) {
        guard presentationTimeStamp > nextRotationPresentationTimeStamp else {
            return
        }
        logger.info("recorder: Starting rotation")
        rotating = true
        maximumCurrentPresentationTimeStamp = currentFile.maximumPresentationTimeStamp
        audioRotated = false
        videoRotated = false
    }

    private func stopRotationIfNeeded() {
        guard audioRotated, videoRotated, let nextFile else {
            return
        }
        logger.info("recorder: Rotation completed")
        rotating = false
        setNextRotationPresentationTimeStamp()
        currentFile = nextFile
        createNextFile()
    }

    private func createNextFile() {
        nextFile = File()
        nextFile?.recorder = self
        nextFile?.start(baseUrl: baseUrl,
                        number: currentFile.number + 1,
                        replay: currentFile.replay)
    }

    private func setNextRotationPresentationTimeStamp() {
        nextRotationPresentationTimeStamp = currentPresentationTimeStamp() + CMTime(seconds: 15)
    }
}
