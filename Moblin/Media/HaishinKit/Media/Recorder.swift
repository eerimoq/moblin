import AVFoundation

protocol IORecorderDelegate: AnyObject {
    func recorderFinished()
}

class Recorder: NSObject {
    private var audioOutputSettings: [String: Any] = [:]
    private var videoOutputSettings: [String: Any] = [:]
    private var fileHandle: Atomic<FileHandle?> = .init(nil)
    private var outputChannelsMap: [Int: Int] = [0: 0, 1: 1]
    private var writer: AVAssetWriter?
    private var audioWriterInput: AVAssetWriterInput?
    private var videoWriterInput: AVAssetWriterInput?
    private var audioConverter: AVAudioConverter?
    private var audioOutputFormat: AVAudioFormat?
    private var basePresentationTimeStamp: CMTime = .zero
    weak var delegate: (any IORecorderDelegate)?

    func setAudioChannelsMap(map: [Int: Int]) {
        mixerLockQueue.async {
            self.outputChannelsMap = map
        }
    }

    func startRunning(url: URL, audioOutputSettings: [String: Any], videoOutputSettings: [String: Any]) {
        mixerLockQueue.async {
            self.startRunningInner(
                url: url,
                audioOutputSettings: audioOutputSettings,
                videoOutputSettings: videoOutputSettings
            )
        }
    }

    func stopRunning() {
        mixerLockQueue.async {
            self.stopRunningInner()
        }
    }

    func appendAudio(_ sampleBuffer: CMSampleBuffer) {
        appendAudioInner(sampleBuffer)
    }

    func appendVideo(_ sampleBuffer: CMSampleBuffer) {
        appendVideoInner(sampleBuffer)
    }

    private func appendAudioInner(_ sampleBuffer: CMSampleBuffer) {
        guard let writer,
              let sampleBuffer = convertAudio(sampleBuffer),
              let input = makeAudioWriterInput(sampleBuffer: sampleBuffer),
              isReadyForStartWriting(writer: writer),
              input.isReadyForMoreMediaData,
              let sampleBuffer = sampleBuffer
              .replacePresentationTimeStamp(sampleBuffer.presentationTimeStamp - basePresentationTimeStamp)
        else {
            return
        }
        if !input.append(sampleBuffer) {
            logger.info("""
            recorder: audio: Append failed with \(writer.error?.localizedDescription ?? "") \
            (status: \(writer.status))
            """)
            stopRunningInner()
        }
    }

    private func convertAudio(_ sampleBuffer: CMSampleBuffer) -> CMSampleBuffer? {
        return tryConvertAudio(sampleBuffer) ?? tryConvertAudio(sampleBuffer, makeConverter: true)
    }

    private func tryConvertAudio(_ sampleBuffer: CMSampleBuffer, makeConverter: Bool = false) -> CMSampleBuffer? {
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
            return outputBuffer.makeSampleBuffer(presentationTimeStamp: sampleBuffer.presentationTimeStamp)
        }
    }

    private func appendVideoInner(_ sampleBuffer: CMSampleBuffer) {
        guard let writer,
              let input = makeVideoWriterInput(sampleBuffer: sampleBuffer),
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
            stopRunningInner()
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
        return makeWriterInput(.audio, outputSettings, sampleBuffer: sampleBuffer)
    }

    private func makeAudioWriterInput(sampleBuffer: CMSampleBuffer) -> AVAssetWriterInput? {
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
        return makeWriterInput(.video, outputSettings, sampleBuffer: sampleBuffer)
    }

    private func makeVideoWriterInput(sampleBuffer: CMSampleBuffer) -> AVAssetWriterInput? {
        if videoWriterInput == nil {
            videoWriterInput = createVideoWriterInput(sampleBuffer: sampleBuffer)
        }
        return videoWriterInput
    }

    private func makeWriterInput(_ mediaType: AVMediaType,
                                 _ outputSettings: [String: Any],
                                 sampleBuffer: CMSampleBuffer) -> AVAssetWriterInput
    {
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
            basePresentationTimeStamp = sampleBuffer.presentationTimeStamp
        }
        return input
    }

    private func makeAudioConverter(_ formatDescription: CMFormatDescription?) {
        guard var streamBasicDescription = formatDescription?.audioStreamBasicDescription else {
            return
        }
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
                return .init(
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
            return .init(streamDescription: &basicDescription, channelLayout: layout)
        }
        return .init(streamDescription: &basicDescription)
    }

    private func startRunningInner(url: URL, audioOutputSettings: [String: Any], videoOutputSettings: [String: Any]) {
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
        writer?.preferredOutputSegmentInterval = CMTime(seconds: 5, preferredTimescale: 1)
        writer?.delegate = self
        writer?.initialSegmentStartTime = .zero
        try? Data().write(to: url)
        fileHandle.mutate { $0 = FileHandle(forWritingAtPath: url.path) }
    }

    private func stopRunningInner() {
        guard let writer else {
            logger.info("recorder: Will not stop recording as it is not running")
            return
        }
        guard writer.status == .writing else {
            logger.info("recorder: Failed to finish writing \(writer.error?.localizedDescription ?? "")")
            reset()
            return
        }
        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        writer.finishWriting {
            self.delegate?.recorderFinished()
            dispatchGroup.leave()
        }
        dispatchGroup.wait()
        reset()
    }

    private func reset() {
        writer = nil
        audioWriterInput = nil
        videoWriterInput = nil
        audioConverter = nil
        audioOutputFormat = nil
        basePresentationTimeStamp = .zero
        fileHandle.mutate { $0 = nil }
    }

    private func isReadyForStartWriting(writer: AVAssetWriter) -> Bool {
        return writer.inputs.count == 2
    }
}

extension Recorder: AVAssetWriterDelegate {
    func assetWriter(_: AVAssetWriter,
                     didOutputSegmentData segmentData: Data,
                     segmentType _: AVAssetSegmentType,
                     segmentReport _: AVAssetSegmentReport?)
    {
        fileHandle.value?.write(segmentData)
    }
}
