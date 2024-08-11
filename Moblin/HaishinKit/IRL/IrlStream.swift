import AVFoundation
import Foundation

class IrlStream: NetStream {
    var client: IrlClient?

    override init() {
        client = IrlClient()
        super.init()
    }

    func start() {
        lockQueue.async {
            self.client?.start()
            self.mixer.startEncoding(self)
            self.mixer.startRunning()
        }
    }

    func stop() {
        lockQueue.async {
            self.client?.stop()
            self.client = nil
            self.mixer.stopRunning()
            self.mixer.stopEncoding()
        }
    }
}

extension IrlStream: VideoCodecDelegate {
    func videoCodecOutputFormat(_: VideoCodec, _: CMFormatDescription) {
        client?.writeVideoFormat()
    }

    func videoCodecOutputSampleBuffer(_: VideoCodec, _ sampleBuffer: CMSampleBuffer) {
        client?.writeVideo(sampleBuffer: sampleBuffer)
    }
}

extension IrlStream: AudioCodecDelegate {
    func audioCodecOutputFormat(_: AVAudioFormat) {
        client?.writeAudioFormat()
    }

    func audioCodecOutputBuffer(_ buffer: AVAudioBuffer, _ presentationTimeStamp: CMTime) {
        client?.writeAudio(buffer: buffer, presentationTimeStamp: presentationTimeStamp)
    }
}
