import AVFoundation

protocol IORecorderDelegate: AnyObject {
    func recorderFinished()
    func recorderError()
}

private let lockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.IORecorder.lock")

class Recorder: NSObject {
    private var audioOutputSettings: [String: Any] = [:]
    private var videoOutputSettings: [String: Any] = [:]
    private var fileHandle: FileHandle?
    private var outputChannelsMap: [Int: Int] = [0: 0, 1: 1]
    private var writer: AVAssetWriter?
    private var audioWriterInput: AVAssetWriterInput?
    private var videoWriterInput: AVAssetWriterInput?
    private var audioConverter: AVAudioConverter?
    private var basePresentationTimeStamp: CMTime = .zero
    weak var delegate: (any IORecorderDelegate)?

    func setAudioChannelsMap(map: [Int: Int]) {
        lockQueue.async {
            self.outputChannelsMap = map
        }
    }

    func appendAudio(_ sampleBuffer: CMSampleBuffer) {
        lockQueue.async {
            self.appendAudioInner(sampleBuffer)
        }
    }

    func appendVideo(_ sampleBuffer: CMSampleBuffer) {
        lockQueue.async {
            self.appendVideoInner(sampleBuffer)
        }
    }

    func startRunning(url: URL, audioOutputSettings: [String: Any], videoOutputSettings: [String: Any]) {
        lockQueue.async {
            self.startRunningInner(
                url: url,
                audioOutputSettings: audioOutputSettings,
                videoOutputSettings: videoOutputSettings
            )
        }
    }

    func stopRunning() {
        lockQueue.async {
            self.stopRunningInner()
        }
    }

    private func appendAudioInner(_ sampleBuffer: CMSampleBuffer) {
        guard let writer,
              let sampleBuffer = convert(sampleBuffer),
              let input = makeAudioWriterInput(sampleBuffer: sampleBuffer),
              isReadyForStartWriting(writer: writer, sampleBuffer: sampleBuffer),
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

    private func convert(_ sampleBuffer: CMSampleBuffer) -> CMSampleBuffer? {
        guard let converter = makeAudioConverter(sampleBuffer.formatDescription) else {
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
              isReadyForStartWriting(writer: writer, sampleBuffer: sampleBuffer),
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
        if let sourceFormatHint, let inSourceFormat = sourceFormatHint.streamBasicDescription?.pointee {
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

    private func makeAudioConverter(_ formatDescription: CMFormatDescription?) -> AVAudioConverter? {
        guard audioConverter == nil else {
            return audioConverter
        }
        guard var streamBasicDescription = formatDescription?.streamBasicDescription?.pointee else {
            return nil
        }
        guard let inputFormat = makeAudioFormat(&streamBasicDescription) else {
            return nil
        }
        let outputNumberOfChannels = min(inputFormat.channelCount, 2)
        let outputFormat = AVAudioFormat(
            commonFormat: inputFormat.commonFormat,
            sampleRate: inputFormat.sampleRate,
            channels: outputNumberOfChannels,
            interleaved: inputFormat.isInterleaved
        )!
        audioConverter = AVAudioConverter(from: inputFormat, to: outputFormat)
        audioConverter?.channelMap = makeChannelMap(
            numberOfInputChannels: Int(inputFormat.channelCount),
            numberOfOutputChannels: Int(outputNumberOfChannels),
            outputToInputChannelsMap: outputChannelsMap
        )
        return audioConverter
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
        writer?.outputFileTypeProfile = .mpeg4AppleHLS
        writer?.preferredOutputSegmentInterval = CMTime(seconds: 5, preferredTimescale: 1)
        writer?.delegate = self
        writer?.initialSegmentStartTime = .zero
        try? Data().write(to: url)
        fileHandle = FileHandle(forWritingAtPath: url.path)
    }

    private func stopRunningInner() {
        guard let writer else {
            logger.info("recorder: Will not stop recording as it is not running")
            return
        }
        guard writer.status == .writing else {
            logger.info("recorder: Failed to finish writing \(writer.error?.localizedDescription ?? "")")
            reset()
            delegate?.recorderError()
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
        basePresentationTimeStamp = .zero
        fileHandle = nil
    }

    private func isReadyForStartWriting(writer: AVAssetWriter, sampleBuffer _: CMSampleBuffer) -> Bool {
        return writer.inputs.count == 2
    }
}

extension Recorder: AVAssetWriterDelegate {
    func assetWriter(_: AVAssetWriter, didOutputSegmentData segmentData: Data, segmentType _: AVAssetSegmentType) {
        lockQueue.async {
            self.fileHandle?.write(segmentData)
        }
    }
}
