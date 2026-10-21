@preconcurrency import AVFAudio

final class SpeechSynthesizer: NSObject, @unchecked Sendable {
    private let queue: DispatchQueue
    private let synthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AudioPlayer?
    private var audioFile: AVAudioFile?
    private var audioFileUrl: URL?
    private var onFinished: (() -> Void)?
    private var generation = 0

    init(queue: DispatchQueue) {
        self.queue = queue
        super.init()
    }

    func speak(utterance: AVSpeechUtterance, volume: Float, onFinished: (() -> Void)? = nil) {
        stop()
        self.onFinished = onFinished
        let generation = generation
        synthesizer.write(utterance) { buffer in
            guard let buffer = buffer as? AVAudioPCMBuffer else {
                return
            }
            self.queue.async {
                guard generation == self.generation else {
                    return
                }
                self.handleBuffer(buffer: buffer, volume: volume)
            }
        }
    }

    func stop() {
        generation += 1
        synthesizer.stopSpeaking(at: .immediate)
        audioPlayer?.stop()
        audioPlayer = nil
        audioFile = nil
        removeAudioFile()
        onFinished = nil
    }

    private func handleBuffer(buffer: AVAudioPCMBuffer, volume: Float) {
        if buffer.frameLength == 0 {
            play(volume: volume)
            return
        }
        do {
            if audioFile == nil {
                let url = URL.temporaryDirectory.appendingPathComponent("\(UUID()).caf")
                audioFile = try AVAudioFile(forWriting: url,
                                            settings: buffer.format.settings,
                                            commonFormat: buffer.format.commonFormat,
                                            interleaved: buffer.format.isInterleaved)
                audioFileUrl = url
            }
            try audioFile?.write(from: buffer)
        } catch {
            logger.info("speech-synthesizer: Failed to write audio file: \(error)")
            audioFile = nil
            finished()
        }
    }

    private func play(volume: Float) {
        audioFile = nil
        guard let audioFileUrl else {
            finished()
            return
        }
        do {
            audioPlayer = try AudioPlayer(contentsOf: audioFileUrl)
            audioPlayer?.setDelegate(delegate: self)
            audioPlayer?.setVolume(volume: volume)
            audioPlayer?.play()
        } catch {
            logger.info("speech-synthesizer: Failed to play audio file: \(error)")
            finished()
        }
    }

    private func finished() {
        audioPlayer = nil
        removeAudioFile()
        let onFinished = onFinished
        self.onFinished = nil
        onFinished?()
    }

    private func removeAudioFile() {
        if let audioFileUrl {
            try? FileManager.default.removeItem(at: audioFileUrl)
        }
        audioFileUrl = nil
    }
}

extension SpeechSynthesizer: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_: AVAudioPlayer, successfully _: Bool) {
        queue.async {
            self.finished()
        }
    }
}
