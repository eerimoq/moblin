import AVFoundation
import Collections
import CoreMedia

private struct Input {
    let player: AVAudioPlayerNode
    let format: AVAudioFormat
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
        logger.info("audio-mixer: \(inputId): Adding \(format)")
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
        inputs[inputId] = Input(player: player, format: format, converter: converter)
    }

    func remove(inputId: UUID) {
        logger.info("audio-mixer: \(inputId): Removing")
        if let input = inputs.removeValue(forKey: inputId) {
            engine.detach(input.player)
        }
    }

    func numberOfInputs() -> Int {
        return inputs.count
    }

    func append(inputId: UUID, sampleTime: AVAudioFramePosition, buffer: AVAudioPCMBuffer) {
        guard let input = inputs[inputId] else {
            return
        }
        if let converter = input.converter {
            guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: 1024) else {
                return
            }
            var error: NSError?
            converter.convert(to: convertedBuffer, error: &error) { _, status in
                status.pointee = .haveData
                return buffer
            }
            if let error {
                logger.info("audio-mixer: Conversion error: \(error)")
                return
            }
            input.player.scheduleBuffer(
                convertedBuffer,
                at: AVAudioTime(sampleTime: sampleTime, atRate: input.format.sampleRate)
            )
        } else {
            input.player.scheduleBuffer(
                buffer,
                at: AVAudioTime(sampleTime: sampleTime, atRate: input.format.sampleRate)
            )
        }
    }

    func process() -> AVAudioPCMBuffer? {
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputSamplesPerBuffer) else {
            return nil
        }
        do {
            let status = try engine.renderOffline(outputSamplesPerBuffer, to: outputBuffer)
            logger.info("audio-mixer status \(status)")
        } catch {
            logger.info("audio-mixer: Render error: \(error)")
            return nil
        }
        return outputBuffer
    }
}
