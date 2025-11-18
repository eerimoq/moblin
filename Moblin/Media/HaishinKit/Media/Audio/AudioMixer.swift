import AVFoundation
import Collections
import CoreMedia

private struct Input {
    let format: AVAudioFormat
    let player: AVAudioPlayerNode
    let converter: AVAudioConverter?
}

class AudioMixer {
    private let engine = AVAudioEngine()
    private let outputFormat: AVAudioFormat
    private var inputs: [UUID: Input] = [:]
    private let outputSamplesPerBuffer: AVAudioFrameCount

    init(outputSampleRate: Double, outputChannels: AVAudioChannelCount, outputSamplesPerBuffer: AVAudioFrameCount) {
        self.outputSamplesPerBuffer = outputSamplesPerBuffer
        outputFormat = AVAudioFormat(standardFormatWithSampleRate: outputSampleRate, channels: outputChannels)!
        do {
            try engine.enableManualRenderingMode(
                .offline,
                format: outputFormat,
                maximumFrameCount: outputSamplesPerBuffer
            )
            engine.mainMixerNode.outputVolume = 1
            try engine.start()
        } catch {
            logger.info("audio-mixer: Failed to setup with error: \(error)")
        }
    }

    func add(inputId: UUID, format: AVAudioFormat) {
        logger.info("audio-mixer: \(inputId): Adding input with format: \(format)")
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: outputFormat)
        player.play()
        let converter: AVAudioConverter?
        if format.sampleRate != outputFormat.sampleRate {
            converter = AVAudioConverter(from: format, to: outputFormat)
        } else {
            converter = nil
        }
        inputs[inputId] = Input(format: format, player: player, converter: converter)
    }

    func remove(inputId: UUID) {
        logger.info("audio-mixer: \(inputId): Removing input")
        if let input = inputs.removeValue(forKey: inputId) {
            engine.detach(input.player)
        }
    }

    func numberOfInputs() -> Int {
        return inputs.count
    }

    func append(inputId: UUID, buffer: AVAudioPCMBuffer) {
        guard let input = inputs[inputId] else {
            return
        }
        var buffer = buffer
        if let converter = input.converter {
            guard let resampledBuffer = resample(converter: converter, buffer: buffer) else {
                return
            }
            buffer = resampledBuffer
        }
        input.player.scheduleBuffer(buffer)
    }

    func process() -> AVAudioPCMBuffer? {
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputSamplesPerBuffer) else {
            return nil
        }
        do {
            try engine.renderOffline(outputSamplesPerBuffer, to: outputBuffer)
        } catch {
            logger.info("audio-mixer: Render error: \(error)")
            return nil
        }
        return outputBuffer
    }

    private func resample(converter: AVAudioConverter, buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: 1024) else {
            return nil
        }
        var error: NSError?
        converter.convert(to: convertedBuffer, error: &error) { _, status in
            status.pointee = .haveData
            return buffer
        }
        if let error {
            logger.info("audio-mixer: Conversion error: \(error)")
            return nil
        }
        return convertedBuffer
    }
}
