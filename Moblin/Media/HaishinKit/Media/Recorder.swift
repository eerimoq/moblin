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

private class RecorderFile: NSObject, AVAssetWriterDelegate {
    let fileNumber: Int
    // Accessed on processorPipelineQueue
    var writer: AVAssetWriter?
    var audioWriterInput: AVAssetWriterInput?
    var videoWriterInput: AVAssetWriterInput?
    var basePresentationTimeStamp: CMTime = .zero
    // Accessed on fileWriterQueue
    var fileHandle: FileHandle?
    var initSegment: Data?
    var replay: Bool = false
    weak var recorderDelegate: RecorderDelegate?

    init(fileNumber: Int) {
        self.fileNumber = fileNumber
        super.init()
    }

    func createWriter() {
        writer = AVAssetWriter(contentType: .mpeg4Movie)
        writer?.shouldOptimizeForNetworkUse = true
        writer?.outputFileTypeProfile = .mpeg4AppleHLS
        writer?.preferredOutputSegmentInterval = CMTime(seconds: 2)
        writer?.delegate = self
        writer?.initialSegmentStartTime = .zero
    }

    func createFileHandle(baseUrl: URL) {
        let fileName = String(format: "%04d.mp4", fileNumber)
        let fileUrl = baseUrl.appendingPathComponent(fileName)
        try? Data().write(to: fileUrl)
        fileHandle = FileHandle(forWritingAtPath: fileUrl.path)
    }

    func isReadyForStartWriting() -> Bool {
        guard let writer else { return false }
        return writer.inputs.count == 2
    }

    func finishWriting(completion: @escaping () -> Void) {
        guard let writer else {
            completion()
            return
        }
        guard writer.status == .writing else {
            completion()
            return
        }
        writer.finishWriting(completionHandler: completion)
    }

    func reset() {
        writer = nil
        audioWriterInput = nil
        videoWriterInput = nil
        basePresentationTimeStamp = .zero
        fileWriterQueue.async {
            self.fileHandle = nil
            self.initSegment = nil
        }
    }

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
                    self.recorderDelegate?.recorderInitSegment(data: segmentData)
                case .separable:
                    if let report = segmentReport?.trackReports.first {
                        self.recorderDelegate?.recorderDataSegment(segment: RecorderDataSegment(
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
    private var replay = false
    private var audioOutputSettings: [String: Any] = [:]
    private var videoOutputSettings: [String: Any] = [:]
    private var outputChannelsMap: [Int: Int] = [0: 0, 1: 1]
    private var audioConverter: AVAudioConverter?
    private var audioOutputFormat: AVAudioFormat?
    weak var delegate: RecorderDelegate?
    private var activeFile: RecorderFile?
    private var nextFile: RecorderFile?
    private var baseUrl: URL?
    private var nextFileNumber: Int = 0
    private let rotationInterval: Double = 15 * 60
    private var rotationPending = false
    private var audioPassedRotation = false
    private var videoPassedRotation = false
    private var pendingAudioBuffers: [(CMSampleBuffer, CMTime)] = []
    private var pendingVideoBuffers: [CMSampleBuffer] = []

    func setAudioChannelsMap(map: [Int: Int]) {
        processorPipelineQueue.async {
            self.outputChannelsMap = map
        }
    }

    func startRunning(
        baseUrl: URL?,
        replay: Bool,
        audioOutputSettings: [String: Any],
        videoOutputSettings: [String: Any]
    ) {
        processorPipelineQueue.async {
            self.startRunningInternal(
                baseUrl: baseUrl,
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

    func setUrl(baseUrl: URL?) {
        fileWriterQueue.async {
            if let baseUrl {
                self.activeFile?.createFileHandle(baseUrl: baseUrl)
                if let initSegment = self.activeFile?.initSegment {
                    self.activeFile?.fileHandle?.write(initSegment)
                }
            } else {
                self.activeFile?.fileHandle = nil
            }
        }
    }

    func setReplayBuffering(enabled: Bool) {
        fileWriterQueue.async {
            self.replay = enabled
            self.activeFile?.replay = enabled
            self.nextFile?.replay = enabled
            if let initSegment = self.activeFile?.initSegment {
                self.delegate?.recorderInitSegment(data: initSegment)
            }
        }
    }

    func appendAudio(_ sampleBuffer: CMSampleBuffer, _ presentationTimeStamp: CMTime) {
        guard let activeFile,
              let writer = activeFile.writer,
              let sampleBuffer = convertAudio(sampleBuffer, presentationTimeStamp),
              let input = getAudioWriterInput(file: activeFile, sampleBuffer: sampleBuffer,
                                              presentationTimeStamp),
              activeFile.isReadyForStartWriting(),
              input.isReadyForMoreMediaData
        else {
            return
        }
        if !rotationPending &&
            shouldRotate(file: activeFile, presentationTimeStamp: presentationTimeStamp)
        {
            rotationPending = true
            audioPassedRotation = false
            videoPassedRotation = false
        }
        if rotationPending {
            audioPassedRotation = true
            pendingAudioBuffers.append((sampleBuffer, presentationTimeStamp))
            if audioPassedRotation && videoPassedRotation {
                performRotation()
            }
            return
        }
        guard let adjusted = sampleBuffer
            .replacePresentationTimeStamp(presentationTimeStamp - activeFile.basePresentationTimeStamp)
        else {
            return
        }
        if !input.append(adjusted) {
            logger.info("""
            recorder: audio: Append failed with \(writer.error?.localizedDescription ?? "") \
            (status: \(writer.status))
            """)
            stopRunningInternal()
        }
    }

    func appendVideo(_ sampleBuffer: CMSampleBuffer) {
        guard let activeFile,
              let writer = activeFile.writer,
              let input = getVideoWriterInput(file: activeFile, sampleBuffer: sampleBuffer),
              activeFile.isReadyForStartWriting(),
              input.isReadyForMoreMediaData
        else {
            return
        }
        let presentationTimeStamp = sampleBuffer.presentationTimeStamp
        if !rotationPending &&
            shouldRotate(file: activeFile, presentationTimeStamp: presentationTimeStamp)
        {
            rotationPending = true
            audioPassedRotation = false
            videoPassedRotation = false
        }
        if rotationPending {
            videoPassedRotation = true
            pendingVideoBuffers.append(sampleBuffer)
            if audioPassedRotation && videoPassedRotation {
                performRotation()
            }
            return
        }
        guard let adjusted = sampleBuffer
            .replacePresentationTimeStamp(presentationTimeStamp - activeFile.basePresentationTimeStamp)
        else {
            return
        }
        if !input.append(adjusted) {
            logger.info("""
            recorder: video: Append failed with \(writer.error?.localizedDescription ?? "") \
            (status: \(writer.status))
            """)
            stopRunningInternal()
        }
    }

    // MARK: - Rotation

    private func shouldRotate(file: RecorderFile, presentationTimeStamp: CMTime) -> Bool {
        guard file.basePresentationTimeStamp != .zero else { return false }
        let elapsed = (presentationTimeStamp - file.basePresentationTimeStamp).seconds
        return elapsed >= rotationInterval
    }

    private func performRotation() {
        guard let newFile = nextFile else { return }
        let oldFile = activeFile
        oldFile?.finishWriting {}
        activeFile = newFile
        rotationPending = false
        audioPassedRotation = false
        videoPassedRotation = false
        let baseUrl = self.baseUrl
        fileWriterQueue.async {
            if let baseUrl {
                newFile.createFileHandle(baseUrl: baseUrl)
            }
        }
        writePendingBuffers(to: newFile)
        prepareNextFile()
    }

    private func writePendingBuffers(to file: RecorderFile) {
        if let (firstAudio, firstAudioPTS) = pendingAudioBuffers.first {
            file.audioWriterInput = createAudioWriterInput(
                file: file, sampleBuffer: firstAudio, firstAudioPTS
            )
        }
        if let firstVideo = pendingVideoBuffers.first {
            file.videoWriterInput = createVideoWriterInput(file: file, sampleBuffer: firstVideo)
        }
        guard file.isReadyForStartWriting() else {
            logger.info("recorder: Failed to start writing on rotated file")
            pendingAudioBuffers.removeAll()
            pendingVideoBuffers.removeAll()
            return
        }
        if let (_, firstAudioPTS) = pendingAudioBuffers.first,
           let firstVideo = pendingVideoBuffers.first
        {
            file.basePresentationTimeStamp = min(firstAudioPTS, firstVideo.presentationTimeStamp)
        }
        for (sampleBuffer, pts) in pendingAudioBuffers {
            guard let input = file.audioWriterInput,
                  input.isReadyForMoreMediaData,
                  let adjusted = sampleBuffer
                  .replacePresentationTimeStamp(pts - file.basePresentationTimeStamp)
            else {
                continue
            }
            if !input.append(adjusted) {
                logger.info("recorder: audio: Append to rotated file failed")
            }
        }
        for sampleBuffer in pendingVideoBuffers {
            guard let input = file.videoWriterInput,
                  input.isReadyForMoreMediaData,
                  let adjusted = sampleBuffer
                  .replacePresentationTimeStamp(
                      sampleBuffer.presentationTimeStamp - file.basePresentationTimeStamp)
            else {
                continue
            }
            if !input.append(adjusted) {
                logger.info("recorder: video: Append to rotated file failed")
            }
        }
        pendingAudioBuffers.removeAll()
        pendingVideoBuffers.removeAll()
    }

    private func flushPendingBuffersToActiveFile() {
        guard let activeFile else { return }
        for (sampleBuffer, pts) in pendingAudioBuffers {
            guard let input = activeFile.audioWriterInput,
                  input.isReadyForMoreMediaData,
                  let adjusted = sampleBuffer
                  .replacePresentationTimeStamp(pts - activeFile.basePresentationTimeStamp)
            else {
                continue
            }
            _ = input.append(adjusted)
        }
        for sampleBuffer in pendingVideoBuffers {
            guard let input = activeFile.videoWriterInput,
                  input.isReadyForMoreMediaData,
                  let adjusted = sampleBuffer
                  .replacePresentationTimeStamp(
                      sampleBuffer.presentationTimeStamp - activeFile.basePresentationTimeStamp)
            else {
                continue
            }
            _ = input.append(adjusted)
        }
        pendingAudioBuffers.removeAll()
        pendingVideoBuffers.removeAll()
    }

    // MARK: - File Management

    private func createNewFile() -> RecorderFile {
        nextFileNumber += 1
        let file = RecorderFile(fileNumber: nextFileNumber)
        file.replay = replay
        file.recorderDelegate = delegate
        file.createWriter()
        return file
    }

    private func prepareNextFile() {
        nextFile = createNewFile()
    }

    // MARK: - Audio Conversion

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

    // MARK: - Writer Input Creation

    private func createAudioWriterInput(file: RecorderFile, sampleBuffer: CMSampleBuffer,
                                        _ presentationTimeStamp: CMTime) -> AVAssetWriterInput
    {
        let sourceFormatHint = sampleBuffer.formatDescription
        var outputSettings: [String: Any] = [:]
        if let sourceFormatHint, let inSourceFormat = sourceFormatHint.audioStreamBasicDescription {
            for (key, value) in audioOutputSettings {
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
        return makeWriterInput(file, .audio, outputSettings, sampleBuffer, presentationTimeStamp)
    }

    private func getAudioWriterInput(file: RecorderFile, sampleBuffer: CMSampleBuffer,
                                     _ presentationTimeStamp: CMTime) -> AVAssetWriterInput?
    {
        if file.audioWriterInput == nil {
            file.audioWriterInput = createAudioWriterInput(
                file: file, sampleBuffer: sampleBuffer, presentationTimeStamp
            )
        }
        return file.audioWriterInput
    }

    private func createVideoWriterInput(file: RecorderFile,
                                        sampleBuffer: CMSampleBuffer) -> AVAssetWriterInput?
    {
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
        return makeWriterInput(file, .video, outputSettings, sampleBuffer,
                               sampleBuffer.presentationTimeStamp)
    }

    private func getVideoWriterInput(file: RecorderFile,
                                     sampleBuffer: CMSampleBuffer) -> AVAssetWriterInput?
    {
        if file.videoWriterInput == nil {
            file.videoWriterInput = createVideoWriterInput(file: file, sampleBuffer: sampleBuffer)
        }
        return file.videoWriterInput
    }

    private func makeWriterInput(_ file: RecorderFile,
                                 _ mediaType: AVMediaType,
                                 _ outputSettings: [String: Any],
                                 _ sampleBuffer: CMSampleBuffer,
                                 _ presentationTimeStamp: CMTime) -> AVAssetWriterInput
    {
        if let audioStreamBasicDescription = sampleBuffer.formatDescription?.audioStreamBasicDescription {
            logger.info("""
            recorder: Make writer: Output: \(outputSettings), Input: \(audioStreamBasicDescription)
            """)
        }
        let input = AVAssetWriterInput(
            mediaType: mediaType,
            outputSettings: outputSettings,
            sourceFormatHint: sampleBuffer.formatDescription
        )
        input.expectsMediaDataInRealTime = true
        file.writer?.add(input)
        if file.writer?.inputs.count == 2 {
            file.writer?.startWriting()
            file.writer?.startSession(atSourceTime: .zero)
            file.basePresentationTimeStamp = presentationTimeStamp
        }
        return input
    }

    // MARK: - Audio Format

    private func makeAudioConverter(_ formatDescription: CMFormatDescription?) {
        guard var streamBasicDescription = formatDescription?.audioStreamBasicDescription else {
            return
        }
        logger.info("recorder: Creating converter from \(streamBasicDescription)")
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
        guard let audioOutputFormat else {
            return
        }
        logger.info("recorder: Input: \(inputFormat), output: \(audioOutputFormat)")
        audioConverter = AVAudioConverter(from: inputFormat, to: audioOutputFormat)
        audioConverter?.channelMap = makeChannelMap(
            numberOfInputChannels: Int(inputFormat.channelCount),
            numberOfOutputChannels: Int(audioOutputFormat.channelCount),
            outputToInputChannelsMap: outputChannelsMap
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

    // MARK: - Start / Stop

    private func startRunningInternal(
        baseUrl: URL?,
        replay: Bool,
        audioOutputSettings: [String: Any],
        videoOutputSettings: [String: Any]
    ) {
        self.replay = replay
        self.audioOutputSettings = audioOutputSettings
        self.videoOutputSettings = videoOutputSettings
        self.baseUrl = baseUrl
        guard activeFile == nil else {
            logger.info("recorder: Will not start recording as it is already running or missing URL")
            return
        }
        reset()
        activeFile = createNewFile()
        prepareNextFile()
        setUrl(baseUrl: baseUrl)
    }

    private func stopRunningInternal() {
        if rotationPending {
            flushPendingBuffersToActiveFile()
            rotationPending = false
        }
        guard let activeFile else {
            logger.info("recorder: Will not stop recording as it is not running")
            return
        }
        guard let writer = activeFile.writer, writer.status == .writing else {
            logger.info("""
            recorder: Failed to finish writing \
            \(activeFile.writer?.error?.localizedDescription ?? "")
            """)
            reset()
            return
        }
        activeFile.finishWriting {
            self.delegate?.recorderFinished()
        }
        reset()
    }

    private func reset() {
        activeFile?.reset()
        activeFile = nil
        nextFile?.reset()
        nextFile = nil
        audioConverter = nil
        audioOutputFormat = nil
        baseUrl = nil
        nextFileNumber = 0
        rotationPending = false
        audioPassedRotation = false
        videoPassedRotation = false
        pendingAudioBuffers.removeAll()
        pendingVideoBuffers.removeAll()
    }
}
