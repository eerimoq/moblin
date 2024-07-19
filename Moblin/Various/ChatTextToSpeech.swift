import AVFAudio
import Collections
import NaturalLanguage

private let textToSpeechDispatchQueue = DispatchQueue(label: "com.eerimoq.textToSpeech", qos: .utility)

private struct TextToSpeechMessage {
    let user: String
    let message: String
}

private let saysByLanguage = [
    "en": "says",
    "sv": "säger",
    "no": "sier",
    "es": "dice",
    "de": "sagt",
    "fr": "dit",
    "pl": "mówi",
    "vi": "nói",
    "nl": "zegt",
    "zh": "说",
    "ko": "라고",
    "ru": "говорит",
    "uk": "каже",
]

class ChatTextToSpeech: NSObject {
    private var rate: Float = 0.4
    private var volume: Float = 0.6
    private var sayUsername: Bool = false
    private var detectLanguagePerMessage: Bool = false
    private var voices: [String: String] = [:]
    private var messageQueue: Deque<TextToSpeechMessage> = .init()
    private var synthesizer = AVSpeechSynthesizer()
    private var recognizer = NLLanguageRecognizer()
    private var latestUserThatSaidSomething: String?
    private var filterEnabled: Bool = true
    private var filterMentionsEnabled: Bool = true
    private var running = true

    private func isFilteredOut(message: String) -> Bool {
        if isFilteredOutFilter(message: message) {
            return true
        }
        if isFilteredOutFilterMentions(message: message) {
            return true
        }
        return false
    }

    private func isFilteredOutFilter(message: String) -> Bool {
        if !filterEnabled {
            return false
        }
        let probability = recognizer.languageHypotheses(withMaximum: 1).first?.value ?? 0.0
        if probability < 0.7 && message.count > 30 {
            return true
        }
        if message.hasPrefix("!") {
            return true
        }
        if message.contains("https") {
            return true
        }
        return false
    }

    private func isFilteredOutFilterMentions(message: String) -> Bool {
        if !filterMentionsEnabled {
            return false
        }
        return message.starts(with: "@") || message.contains(" @")
    }

    private func getSays(_ language: String) -> String {
        return saysByLanguage[language] ?? ""
    }

    private func getVoice(message: String) -> (AVSpeechSynthesisVoice?, String)? {
        recognizer.reset()
        recognizer.processString(message)
        guard !isFilteredOut(message: message) else {
            return nil
        }
        var language = recognizer.dominantLanguage?.rawValue
        if !detectLanguagePerMessage || language == nil {
            language = Locale.current.language.languageCode?.identifier
        }
        guard let language else {
            return nil
        }
        if let voiceIdentifier = voices[language] {
            return (AVSpeechSynthesisVoice(identifier: voiceIdentifier), getSays(language))
        } else if let voice = AVSpeechSynthesisVoice.speechVoices()
            .filter({ $0.language.starts(with: language) }).first
        {
            return (AVSpeechSynthesisVoice(identifier: voice.identifier), getSays(language))
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
        guard let (voice, says) = getVoice(message: message.message) else {
            return
        }
        guard let voice else {
            return
        }
        let text: String
        if message.user == latestUserThatSaidSomething || !sayUsername {
            text = message.message
        } else {
            text = String(localized: "\(message.user) \(says): \(message.message)")
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = rate
        utterance.pitchMultiplier = 0.8
        utterance.preUtteranceDelay = 0.05
        utterance.volume = volume
        utterance.voice = voice
        synthesizer.speak(utterance)
        latestUserThatSaidSomething = message.user
    }

    func say(user: String, message: String) {
        textToSpeechDispatchQueue.async {
            guard self.running else {
                return
            }
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

    func setFilter(value: Bool) {
        textToSpeechDispatchQueue.async {
            self.filterEnabled = value
        }
    }

    func setFilterMentions(value: Bool) {
        textToSpeechDispatchQueue.async {
            self.filterMentionsEnabled = value
        }
    }

    func setDetectLanguagePerMessage(value: Bool) {
        textToSpeechDispatchQueue.async {
            self.detectLanguagePerMessage = value
        }
    }

    func reset(running: Bool) {
        textToSpeechDispatchQueue.async {
            self.running = running
            self.synthesizer.stopSpeaking(at: .word)
            self.latestUserThatSaidSomething = nil
            self.messageQueue.removeAll()
            self.synthesizer = AVSpeechSynthesizer()
            self.synthesizer.delegate = self
            self.recognizer = NLLanguageRecognizer()
        }
    }

    func skipCurrentMessage() {
        textToSpeechDispatchQueue.async {
            self.synthesizer.stopSpeaking(at: .word)
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
