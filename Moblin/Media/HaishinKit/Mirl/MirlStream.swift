import AVFoundation
import Foundation

class MirlStream {
    var client: MirlClient?
    private let processor: Processor

    init(processor: Processor) {
        self.processor = processor
        client = MirlClient()
    }

    func start() {
        processorControlQueue.async {
            self.client?.start()
            self.processor.startEncoding(self)
        }
    }

    func stop() {
        processorControlQueue.async {
            self.client?.stop()
            self.client = nil
            self.processor.stopEncoding(self)
        }
    }
}

extension MirlStream: VideoEncoderDelegate {
    func videoEncoderOutputFormat(_: VideoEncoder, _ formatDescription: CMFormatDescription) {
        client?.writeVideoFormat(formatDescription: formatDescription)
    }

    func videoEncoderOutputSampleBuffer(_: VideoEncoder, _ sampleBuffer: CMSampleBuffer) {
        client?.writeVideo(sampleBuffer: sampleBuffer)
    }
}

extension MirlStream: AudioCodecDelegate {
    func audioCodecOutputFormat(_ audioFormat: AVAudioFormat) {
        client?.writeAudioFormat(audioFormat: audioFormat)
    }

    func audioCodecOutputBuffer(_ buffer: AVAudioBuffer, _ presentationTimeStamp: CMTime) {
        client?.writeAudio(buffer: buffer, presentationTimeStamp: presentationTimeStamp)
    }
}
