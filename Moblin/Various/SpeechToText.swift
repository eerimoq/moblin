import AVKit
import Speech

protocol SpeechToTextDelegate: AnyObject {
    func speechToTextPartialResult(position: Int, text: String)
    func speechToTextClear()
}

class SpeechToText: NSObject {
    private let speechRecognizer = SFSpeechRecognizer()
    private var recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
    private var recognitionTask: SFSpeechRecognitionTask?
    weak var delegate: SpeechToTextDelegate?
    private var latestResultTime: ContinuousClock.Instant = .now
    private var hasResult = false
    private var running = false
    private var isStarted = false
    private var frozenText = ""
    private var frozenTextPosition = 0
    private var previousBestTranscription = ""

    func start(onError: @escaping (String) -> Void) {
        isStarted = true
        clearFrozenText()
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
        hasResult = false
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
        if hasResult, latestResultTime.duration(to: now) > .seconds(2) {
            running = false
            recognitionRequest.endAudio()
        }
        if latestResultTime.duration(to: now) > .seconds(5) {
            if !frozenText.isEmpty {
                clearFrozenText()
                delegate?.speechToTextClear()
            }
        }
    }

    private func clearFrozenText() {
        frozenText = ""
        frozenTextPosition = 0
    }

    private func startAuthorized() {
        stopInternal()
        startRecognition()
    }

    private func startRecognition() {
        guard isStarted else {
            return
        }
        let newFrozenText = frozenText + previousBestTranscription
        frozenText = String(newFrozenText.suffix(150)).trim()
        frozenTextPosition += newFrozenText.count - frozenText.count
        if !frozenText.isEmpty {
            frozenText += " "
        }
        hasResult = false
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
                    self.delegate?.speechToTextPartialResult(
                        position: self.frozenTextPosition,
                        text: self.frozenText + text
                    )
                    self.latestResultTime = .now
                    self.hasResult = true
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
