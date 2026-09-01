import AVFoundation
import CoreAudio

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

private let maximumAudioPresentationTimeStampOffset = 0.01

private let queue = DispatchQueue(label: "com.eerimoq.recorder")
private let fileWriterQueue = DispatchQueue(label: "com.eerimoq.recorder-file-writer")

final class Recorder: NSObject, @unchecked Sendable {
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
    private var audioOutputFormat: AVAudioFormat?
    private var basePresentationTimeStamp: CMTime = .invalid
    private var nextAudioPresentationTimeStamp: CMTime = .invalid
    private var isRecording: Bool = false
    weak var delegate: (any RecorderDelegate)?

    func setAudioChannelsMap(map: [Int: Int]) {
        queue.async {
            self.outputChannelsMap = map
        }
    }

    func startRunning(
        url: URL?,
        replay: Bool,
        audioOutputSettings: [String: Any],
        videoOutputSettings: [String: Any]
    ) {
        nonisolated(unsafe)
        let audioOutputSettings = audioOutputSettings
        nonisolated(unsafe)
        let videoOutputSettings = videoOutputSettings
        queue.async {
            self.startRunningInternal(
                url: url,
                replay: replay,
                audioOutputSettings: audioOutputSettings,
                videoOutputSettings: videoOutputSettings
            )
        }
        processorPipelineQueue.async {
            self.isRecording = true
        }
    }

    func stopRunning() {
        queue.async {
            self.stopRunningInternal()
        }
        processorPipelineQueue.async {
            self.isRecording = false
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
        guard isRecording else {
            return
        }
        queue.async {
            self.appendAudioInternal(sampleBuffer, presentationTimeStamp)
        }
    }

    func appendVideo(_ sampleBuffer: CMSampleBuffer) {
        guard isRecording else {
            return
        }
        queue.async {
            self.appendVideoInternal(sampleBuffer)
        }
    }

    private func appendAudioInternal(_ sampleBuffer: CMSampleBuffer, _ presentationTimeStamp: CMTime) {
        guard let writer,
              let convertedSampleBuffer = convertAudio(sampleBuffer, presentationTimeStamp),
              let input = getAudioWriterInput(sampleBuffer: convertedSampleBuffer),
              let duration = makeAudioDuration(numberOfFrames: convertedSampleBuffer.numSamples),
              isReadyForStartWriting(writer: writer),
              input.isReadyForMoreMediaData,
              basePresentationTimeStamp.isValid
        else {
            return
        }
        let presentationTimeStamp = presentationTimeStamp - basePresentationTimeStamp
        guard presentationTimeStamp >= .zero else {
            return
        }
        if !nextAudioPresentationTimeStamp.isValid {
            nextAudioPresentationTimeStamp = .zero
        }
        let offset = (presentationTimeStamp - nextAudioPresentationTimeStamp).seconds
        if offset < -maximumAudioPresentationTimeStampOffset {
            return
        }
        if offset > maximumAudioPresentationTimeStampOffset {
            appendAudioSilence(writer, input, nextAudioPresentationTimeStamp, presentationTimeStamp)
        }
        guard let sampleBuffer = convertedSampleBuffer.replacePresentationTimeStamp(presentationTimeStamp)
        else {
            return
        }
        guard appendAudioSampleBuffer(writer, input, sampleBuffer) else {
            return
        }
        nextAudioPresentationTimeStamp = presentationTimeStamp + duration
    }

    private func makeAudioDuration(numberOfFrames: Int) -> CMTime? {
        guard let outputFormat = audioConverter?.outputFormat else {
            return nil
        }
        return CMTime(value: CMTimeValue(numberOfFrames), timescale: CMTimeScale(outputFormat.sampleRate))
    }

    private func appendAudioSilence(_ writer: AVAssetWriter,
                                    _ input: AVAssetWriterInput,
                                    _ from: CMTime,
                                    _ to: CMTime)
    {
        guard let outputFormat = audioConverter?.outputFormat else {
            return
        }
        let numberOfFrames = UInt32(((to - from).seconds * outputFormat.sampleRate).rounded())
        guard numberOfFrames > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: numberOfFrames)
        else {
            return
        }
        buffer.frameLength = numberOfFrames
        for audioBuffer in UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList) {
            guard let data = audioBuffer.mData else {
                continue
            }
            memset(data, 0, Int(audioBuffer.mDataByteSize))
        }
        guard let sampleBuffer = buffer.makeSampleBuffer(from) else {
            return
        }
        logger.info("""
        recorder: audio: Inserting \(formatThreeDecimals((to - from).seconds)) seconds of silence at \
        \(formatThreeDecimals(from.seconds))
        """)
        _ = appendAudioSampleBuffer(writer, input, sampleBuffer)
    }

    private func appendAudioSampleBuffer(_ writer: AVAssetWriter,
                                         _ input: AVAssetWriterInput,
                                         _ sampleBuffer: CMSampleBuffer) -> Bool
    {
        guard input.append(sampleBuffer) else {
            logger.info("""
            recorder: audio: Append failed with \(writer.error?.localizedDescription ?? "") \
            (status: \(writer.status))
            """)
            stopRunningInternal()
            return false
        }
        return true
    }

    private func appendVideoInternal(_ sampleBuffer: CMSampleBuffer) {
        guard let writer,
              let input = getVideoWriterInput(sampleBuffer: sampleBuffer),
              isReadyForStartWriting(writer: writer),
              input.isReadyForMoreMediaData
        else {
            return
        }
        if !basePresentationTimeStamp.isValid {
            basePresentationTimeStamp = sampleBuffer.presentationTimeStamp
        }
        guard let sampleBuffer = sampleBuffer
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

    private func convertAudio(_ sampleBuffer: CMSampleBuffer,
                              _ presentationTimeStamp: CMTime) -> CMSampleBuffer?
    {
        tryConvertAudio(sampleBuffer, presentationTimeStamp, makeConverter: false)
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

    private func createAudioWriterInput(sampleBuffer: CMSampleBuffer) -> AVAssetWriterInput {
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
        return makeWriterInput(.audio, outputSettings, sampleBuffer)
    }

    private func getAudioWriterInput(sampleBuffer: CMSampleBuffer) -> AVAssetWriterInput? {
        if audioWriterInput == nil {
            audioWriterInput = createAudioWriterInput(sampleBuffer: sampleBuffer)
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
        return makeWriterInput(.video, outputSettings, sampleBuffer)
    }

    private func getVideoWriterInput(sampleBuffer: CMSampleBuffer) -> AVAssetWriterInput? {
        if videoWriterInput == nil {
            videoWriterInput = createVideoWriterInput(sampleBuffer: sampleBuffer)
        }
        return videoWriterInput
    }

    private func makeWriterInput(_ mediaType: AVMediaType,
                                 _ outputSettings: [String: Any],
                                 _ sampleBuffer: CMSampleBuffer) -> AVAssetWriterInput
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
        guard let audioOutputFormat else {
            return
        }
        logger.debug("recorder: Input: \(inputFormat), output: \(audioOutputFormat)")
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
        writer = AVAssetWriter(contentType: .mpeg4Movie)
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
        audioOutputFormat = nil
        basePresentationTimeStamp = .invalid
        nextAudioPresentationTimeStamp = .invalid
        fileWriterQueue.async {
            self.fileHandle = nil
            self.initSegment = nil
        }
    }

    private func isReadyForStartWriting(writer: AVAssetWriter) -> Bool {
        writer.inputs.count == 2
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
