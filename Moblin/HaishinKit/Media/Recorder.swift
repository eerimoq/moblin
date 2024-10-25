import AVFoundation

protocol IORecorderDelegate: AnyObject {
    func recorder(_ recorder: Recorder, finishWriting writer: AVAssetWriter)
}

private let lockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.IORecorder.lock")

class Recorder {
    private static let defaultAudioOutputSettings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey: 0,
        AVNumberOfChannelsKey: 0,
    ]

    private static let defaultVideoOutputSettings: [String: Any] = [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoHeightKey: 0,
        AVVideoWidthKey: 0,
    ]

    weak var delegate: (any IORecorderDelegate)?
    var audioOutputSettings = Recorder.defaultAudioOutputSettings
    var videoOutputSettings = Recorder.defaultVideoOutputSettings
    var url: URL?
    private var outputChannelsMap: [Int: Int] = [0: 0, 1: 1]

    private func isReadyForStartWriting() -> Bool {
        return writer?.inputs.count == 2
    }

    private var writer: AVAssetWriter?
    private var audioWriterInput: AVAssetWriterInput?
    private var videoWriterInput: AVAssetWriterInput?
    private var audioConverter: AVAudioConverter?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var dimensions: CMVideoDimensions = .init(width: 0, height: 0)

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

    func appendVideo(_ pixelBuffer: CVPixelBuffer, withPresentationTime: CMTime) {
        lockQueue.async {
            self.appendVideoInner(pixelBuffer, withPresentationTime: withPresentationTime)
        }
    }

    func startRunning() {
        lockQueue.async {
            self.startRunningInner()
        }
    }

    func stopRunning() {
        lockQueue.async {
            self.stopRunningInner()
        }
    }

    private func appendAudioInner(_ sampleBuffer: CMSampleBuffer) {
        guard let writer else {
            return
        }
        let sampleBuffer = convert(sampleBuffer)
        guard
            let input = makeAudioWriterInput(sourceFormatHint: sampleBuffer.formatDescription),
            isReadyForStartWriting()
        else {
            return
        }
        if writer.status == .unknown {
            writer.startWriting()
            writer.startSession(atSourceTime: sampleBuffer.presentationTimeStamp)
        }
        guard input.isReadyForMoreMediaData else {
            return
        }
        if !input.append(sampleBuffer) {
            logger.info("Failed to append audio \(writer.error?.localizedDescription ?? "")")
        }
    }

    private func convert(_ sampleBuffer: CMSampleBuffer) -> CMSampleBuffer {
        var sampleBuffer = sampleBuffer
        guard
            let converter = makeAudioConverter(sampleBuffer.formatDescription)
        else {
            return sampleBuffer
        }
        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: converter.outputFormat,
            frameCapacity: UInt32(sampleBuffer.numSamples)
        ) else {
            return sampleBuffer
        }
        do {
            try sampleBuffer.withAudioBufferList { list, _ in
                guard #available(iOS 15.0, *) else {
                    return
                }
                guard let inputBuffer = AVAudioPCMBuffer(
                    pcmFormat: converter.inputFormat,
                    bufferListNoCopy: list.unsafePointer
                ) else {
                    return
                }
                try converter.convert(to: outputBuffer, from: inputBuffer)
                sampleBuffer = outputBuffer
                    .makeSampleBuffer(presentationTimeStamp: sampleBuffer.presentationTimeStamp)!
            }
        } catch {}
        return sampleBuffer
    }

    private func appendVideoInner(_ pixelBuffer: CVPixelBuffer, withPresentationTime: CMTime) {
        guard let writer else {
            return
        }
        if dimensions.width != pixelBuffer.width || dimensions.height != pixelBuffer.height {
            dimensions = .init(width: Int32(pixelBuffer.width), height: Int32(pixelBuffer.height))
        }
        guard
            let input = makeVideoWriterInput(),
            let adaptor = makePixelBufferAdaptor(input),
            isReadyForStartWriting()
        else {
            return
        }
        if writer.status == .unknown {
            writer.startWriting()
            writer.startSession(atSourceTime: withPresentationTime)
        }
        guard input.isReadyForMoreMediaData else {
            return
        }
        if !adaptor.append(pixelBuffer, withPresentationTime: withPresentationTime) {
            logger.info("Failed to append video \(writer.error?.localizedDescription ?? "")")
        }
    }

    private func createAudioWriterInput(sourceFormatHint: CMFormatDescription?) -> AVAssetWriterInput? {
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
        return makeWriterInput(.audio, outputSettings, sourceFormatHint: sourceFormatHint)
    }

    private func makeAudioWriterInput(sourceFormatHint: CMFormatDescription?) -> AVAssetWriterInput? {
        if audioWriterInput == nil {
            audioWriterInput = createAudioWriterInput(sourceFormatHint: sourceFormatHint)
        }
        return audioWriterInput
    }

    private func createVideoWriterInput() -> AVAssetWriterInput? {
        var outputSettings: [String: Any] = [:]
        for (key, value) in videoOutputSettings {
            switch key {
            case AVVideoHeightKey:
                outputSettings[key] = isZero(value) ? Int(dimensions.height) : value
            case AVVideoWidthKey:
                outputSettings[key] = isZero(value) ? Int(dimensions.width) : value
            default:
                outputSettings[key] = value
            }
        }
        return makeWriterInput(.video, outputSettings, sourceFormatHint: nil)
    }

    private func makeVideoWriterInput() -> AVAssetWriterInput? {
        if videoWriterInput == nil {
            videoWriterInput = createVideoWriterInput()
        }
        return videoWriterInput
    }

    private func makeWriterInput(_ mediaType: AVMediaType,
                                 _ outputSettings: [String: Any],
                                 sourceFormatHint: CMFormatDescription?) -> AVAssetWriterInput?
    {
        var input: AVAssetWriterInput?
        input = AVAssetWriterInput(
            mediaType: mediaType,
            outputSettings: outputSettings,
            sourceFormatHint: sourceFormatHint
        )
        input?.expectsMediaDataInRealTime = true
        if let input {
            writer?.add(input)
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

    private func makePixelBufferAdaptor(_ writerInput: AVAssetWriterInput)
        -> AVAssetWriterInputPixelBufferAdaptor?
    {
        if pixelBufferAdaptor == nil {
            pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: writerInput,
                sourcePixelBufferAttributes: [:]
            )
        }
        return pixelBufferAdaptor
    }

    private func startRunningInner() {
        guard writer == nil, let url else {
            logger.info("Will not start recording as it is already running or missing URL")
            return
        }
        reset()
        do {
            writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        } catch {
            logger.info("Failed to create asset writer \(error)")
        }
    }

    private func stopRunningInner() {
        guard let writer else {
            logger.info("Will not stop recording as it is not running")
            return
        }
        guard writer.status == .writing else {
            logger.info("Failed to finish writing \(writer.error?.localizedDescription ?? "")")
            reset()
            return
        }
        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        writer.finishWriting {
            self.delegate?.recorder(self, finishWriting: writer)
            self.reset()
            dispatchGroup.leave()
        }
        dispatchGroup.wait()
    }

    private func reset() {
        writer = nil
        audioWriterInput = nil
        videoWriterInput = nil
        pixelBufferAdaptor = nil
        dimensions = .init(width: 0, height: 0)
    }
}
