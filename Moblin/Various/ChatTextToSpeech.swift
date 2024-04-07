import AVFAudio
import Collections
import NaturalLanguage

private let textToSpeechDispatchQueue = DispatchQueue(label: "com.eerimoq.textToSpeech", qos: .utility)

private struct TextToSpeechMessage {
    let user: String
    let message: String
}

class ChatTextToSpeech: NSObject {
    private var rate: Float = 0.4
    private var volume: Float = 0.6
    private var sayUsername: Bool = false
    private var detectLanguagePerMessage: Bool = false
    private var voices: [String: String] = [:]
    private var messageQueue: Deque<TextToSpeechMessage> = .init()
    private var synthesizer = AVSpeechSynthesizer()
    private var recognizer = NLLanguageRecognizer()
    private var latestUserThatSaidSomething = ""

    private func getVoice(message: String) -> AVSpeechSynthesisVoice? {
        recognizer.reset()
        recognizer.processString(message)
        var language = recognizer.dominantLanguage?.rawValue
        let probability = recognizer.languageHypotheses(withMaximum: 1).first?.value ?? 0.0
        if probability < 0.7 && message.count > 8 {
            return nil
        }
        if !detectLanguagePerMessage || language == nil {
            language = Locale.current.language.languageCode?.identifier
        }
        guard let language else {
            return nil
        }
        if let voiceIdentifier = voices[language] {
            return AVSpeechSynthesisVoice(identifier: voiceIdentifier)
        } else if let voice = AVSpeechSynthesisVoice.speechVoices()
            .filter({ $0.language.starts(with: language) }).first
        {
            return AVSpeechSynthesisVoice(identifier: voice.identifier)
        }
        return nil
    }

    private func trySayNextMessage() {
        guard !synthesizer.isSpeaking else {
            return
        }
        guard let message = messageQueue.popFirst() else {
            return
        }
        let text: String
        if message.user == latestUserThatSaidSomething || !sayUsername {
            text = message.message
        } else {
            text = String(localized: "\(message.user) says: \(message.message)")
        }
        latestUserThatSaidSomething = message.user
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = rate
        utterance.pitchMultiplier = 0.8
        utterance.preUtteranceDelay = 0.05
        utterance.volume = volume
        guard let voice = getVoice(message: message.message) else {
            return
        }
        utterance.voice = voice
        synthesizer.speak(utterance)
    }

    func say(user: String, message: String) {
        textToSpeechDispatchQueue.async {
            self.messageQueue.append(.init(user: user, message: message))
            self.trySayNextMessage()
        }
    }

    func setRate(rate: Float) {
        textToSpeechDispatchQueue.async {
            self.rate = rate
        }
    }

    func setVolume(volume: Float) {
        textToSpeechDispatchQueue.async {
            self.volume = volume
        }
    }

    func setVoices(voices: [String: String]) {
        textToSpeechDispatchQueue.async {
            self.voices = voices
        }
    }

    func setSayUsername(value: Bool) {
        textToSpeechDispatchQueue.async {
            self.sayUsername = value
        }
    }

    func setDetectLanguagePerMessage(value: Bool) {
        textToSpeechDispatchQueue.async {
            self.detectLanguagePerMessage = value
        }
    }

    func reset() {
        textToSpeechDispatchQueue.async {
            self.synthesizer.stopSpeaking(at: .word)
            self.latestUserThatSaidSomething = ""
            self.messageQueue.removeAll()
            self.synthesizer = AVSpeechSynthesizer()
            self.synthesizer.delegate = self
            self.recognizer = NLLanguageRecognizer()
        }
    }

    func skipCurrentMessage() {
        textToSpeechDispatchQueue.async {
            self.synthesizer.stopSpeaking(at: .immediate)
            self.trySayNextMessage()
        }
    }
}

extension ChatTextToSpeech: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_: AVSpeechSynthesizer, didFinish _: AVSpeechUtterance) {
        textToSpeechDispatchQueue.async {
            self.trySayNextMessage()
        }
    }
}
