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
    private var oldText = ""
    private var previousBestTranscription = ""

    func start(onError: @escaping (String) -> Void) {
        isStarted = true
        oldText = ""
        previousBestTranscription = ""
        speechRecognizer?.delegate = self
        SFSpeechRecognizer.requestAuthorization { authStatus in
            switch authStatus {
            case .authorized:
                OperationQueue.main.addOperation {
                    self.startAuthorized()
                }
            case .denied:
                onError("Speech recognition not allowed")
            case .restricted:
                onError("Speech recognition restricted on this device")
            case .notDetermined:
                onError("Speech recognition not yet authorized")
            @unknown default:
                onError("Speech recognition error")
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
        oldText = String((oldText + " " + previousBestTranscription).suffix(100))
        latestResultTime = nil
        running = true
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.addsPunctuation = false
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
                    self.delegate?.speechToTextPartialResult(text: self.oldText + " " + text)
                    self.latestResultTime = .now
                }
                self.previousBestTranscription = text
            }
        )
    }
}

extension SpeechToText: SFSpeechRecognizerDelegate {
    func speechRecognizer(_: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        logger.info("speech-to-text: Available \(available)")
    }
}
