import AVKit
import Speech

protocol SpeechToTextDelegate: AnyObject {
    func speechToTextPartialResult(text: String)
}

class SpeechToText: NSObject {
    private let speechRecognizer =
        SFSpeechRecognizer() // SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
    private var recognitionTask: SFSpeechRecognitionTask?
    weak var delegate: SpeechToTextDelegate?
    private var latestResultTime: ContinuousClock.Instant?
    private var running = false
    private var isStarted = false

    func start() {
        isStarted = true
        speechRecognizer?.delegate = self
        SFSpeechRecognizer.requestAuthorization { authStatus in
            switch authStatus {
            case .authorized:
                OperationQueue.main.addOperation {
                    self.startAuthorized()
                }
            case .denied:
                logger.info("speech-to-text: User denied access to speech recognition")
            case .restricted:
                logger.info("speech-to-text: Speech recognition restricted on this device")
            case .notDetermined:
                logger.info("speech-to-text: Speech recognition not yet authorized")
            @unknown default:
                logger.info("speech-to-text: Speech recognition unknown error")
            }
        }
    }

    func stop() {
        isStarted = false
        stopInternal()
    }

    private func stopInternal() {
        recognitionTask?.cancel()
        recognitionTask = nil
        latestResultTime = nil
        running = false
    }

    func append(sampleBuffer: CMSampleBuffer) {
        guard running else {
            return
        }
        recognitionRequest.appendAudioSampleBuffer(sampleBuffer)
    }

    func tick(now: ContinuousClock.Instant) {
        guard running else {
            return
        }
        guard let latestResultTime, latestResultTime.duration(to: now) > .seconds(2) else {
            return
        }
        running = false
        recognitionRequest.endAudio()
    }

    private func startAuthorized() {
        stopInternal()
        startRecognition()
    }

    private func startRecognition() {
        guard isStarted else {
            return
        }
        latestResultTime = nil
        running = true
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.addsPunctuation = false
        // recognitionRequest?.requiresOnDeviceRecognition = true // gives error 1101
        recognitionTask = speechRecognizer?.recognitionTask(
            with: recognitionRequest,
            resultHandler: { result, error in
                if let error {
                    logger.debug("speech-to-text: Error \(error)")
                    self.startRecognition()
                    return
                }
                guard let result else {
                    self.startRecognition()
                    return
                }
                let text = result.bestTranscription.formattedString
                if result.isFinal {
                    self.startRecognition()
                } else {
                    self.latestResultTime = .now
                    self.delegate?.speechToTextPartialResult(text: text)
                }
            }
        )
    }
}

extension SpeechToText: SFSpeechRecognizerDelegate {
    func speechRecognizer(_: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        logger.info("speech-to-text: Available \(available)")
    }
}
