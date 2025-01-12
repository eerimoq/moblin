import AVFoundation
import Foundation

class MirlStream: NetStream {
    var client: MirlClient?

    override init() {
        client = MirlClient()
        super.init()
    }

    func start() {
        netStreamLockQueue.async {
            self.client?.start()
            self.mixer.startEncoding(self)
            self.mixer.startRunning()
        }
    }

    func stop() {
        netStreamLockQueue.async {
            self.client?.stop()
            self.client = nil
            self.mixer.stopRunning()
            self.mixer.stopEncoding()
        }
    }
}

extension MirlStream: VideoCodecDelegate {
    func videoCodecOutputFormat(_: VideoCodec, _ formatDescription: CMFormatDescription) {
        client?.writeVideoFormat(formatDescription: formatDescription)
    }

    func videoCodecOutputSampleBuffer(_: VideoCodec, _ sampleBuffer: CMSampleBuffer) {
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
