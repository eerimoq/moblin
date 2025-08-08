import AVFAudio
import Collections
import NaturalLanguage

private let textToSpeechDispatchQueue = DispatchQueue(label: "com.eerimoq.textToSpeech", qos: .utility)

private struct TextToSpeechMessage {
    let messageId: String?
    let userId: String?
    let user: String
    let message: String
    let isRedemption: Bool
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
    "it": "dice",
    "ja": "言う",
]

class ChatTextToSpeech: NSObject {
    private var rate: Float = 0.4
    private var volume: Float = 0.6
    private var sayUsername: Bool = false
    private var detectLanguagePerMessage: Bool = false
    private var pauseBetweenMessages: Double = 0.0
    private var voices: [String: String] = [:]
    private var messageQueue: Deque<TextToSpeechMessage> = .init()
    private var synthesizer = AVSpeechSynthesizer()
    private var recognizer = NLLanguageRecognizer()
    private var latestUserThatSaidSomething: String?
    private var sayLatestUserThatSaidSomethingAgain = ContinuousClock.now
    private var filterEnabled: Bool = true
    private var filterMentionsEnabled: Bool = true
    private var streamerMentions: [String] = []
    private var running = true
    private var paused = false
    private var currentlyPlayingMessage: TextToSpeechMessage?

    func say(messageId: String?, user: String, userId: String?, message: String, isRedemption: Bool) {
        textToSpeechDispatchQueue.async {
            guard self.running else {
                return
            }
            self.messageQueue.append(.init(
                messageId: messageId,
                userId: userId,
                user: user,
                message: message,
                isRedemption: isRedemption
            ))
            self.trySayNextMessage()
        }
    }

    func delete(messageId: String) {
        textToSpeechDispatchQueue.async {
            self.messageQueue = self.messageQueue.filter { $0.messageId != messageId }
            if self.currentlyPlayingMessage?.messageId == messageId {
                self.skipCurrentMessageInternal()
            }
        }
    }

    func delete(userId: String) {
        textToSpeechDispatchQueue.async {
            self.messageQueue = self.messageQueue.filter { $0.userId != userId }
            if self.currentlyPlayingMessage?.userId == userId {
                self.skipCurrentMessageInternal()
            }
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

    func setStreamerMentions(streamerMentions: [String]) {
        textToSpeechDispatchQueue.async {
            self.streamerMentions = streamerMentions
        }
    }

    func setDetectLanguagePerMessage(value: Bool) {
        textToSpeechDispatchQueue.async {
            self.detectLanguagePerMessage = value
        }
    }

    func setPauseBetweenMessages(value: Double) {
        textToSpeechDispatchQueue.async {
            self.pauseBetweenMessages = value
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
            self.skipCurrentMessageInternal()
        }
    }

    func play() {
        textToSpeechDispatchQueue.async {
            self.paused = false
            self.trySayNextMessage()
        }
    }

    func pause() {
        textToSpeechDispatchQueue.async {
            self.paused = true
        }
    }

    private func skipCurrentMessageInternal() {
        synthesizer.stopSpeaking(at: .word)
        synthesizer = AVSpeechSynthesizer()
        synthesizer.delegate = self
        currentlyPlayingMessage = nil
        trySayNextMessage()
    }

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
        if message.starts(with: "@") || message.contains(" @") {
            for streamerMention in streamerMentions {
                if let range = message.range(of: streamerMention) {
                    if isStreamerMention(
                        message: message,
                        mentionLowerBound: range.lowerBound,
                        mentionUpperBound: range.upperBound
                    ) {
                        return false
                    }
                }
            }
            return true
        }
        return false
    }

    private func isStreamerMention(
        message: String,
        mentionLowerBound: String.Index,
        mentionUpperBound: String.Index
    ) -> Bool {
        // There is always a space at the end of the message, so this should never happen.
        guard mentionUpperBound < message.endIndex else {
            return false
        }
        if mentionLowerBound > message.startIndex {
            if message[message.index(before: mentionLowerBound)] != " " {
                return false
            }
        }
        if message[mentionUpperBound] != " " {
            return false
        }
        return true
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
        guard !paused else {
            return
        }
        guard !synthesizer.isSpeaking else {
            return
        }
        guard let message = messageQueue.popFirst() else {
            return
        }
        currentlyPlayingMessage = message
        guard let (voice, says) = getVoice(message: message.message) else {
            return
        }
        guard let voice else {
            return
        }
        let text: String
        let now = ContinuousClock.now
        if message.isRedemption {
            text = "\(message.user) \(message.message)"
        } else if !shouldSayUser(user: message.user, now: now) || !sayUsername {
            text = message.message
        } else {
            text = String(localized: "\(message.user) \(says): \(message.message)")
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = rate
        utterance.pitchMultiplier = 0.8
        utterance.preUtteranceDelay = pauseBetweenMessages
        utterance.volume = volume
        utterance.voice = voice
        synthesizer.speak(utterance)
        latestUserThatSaidSomething = message.user
        sayLatestUserThatSaidSomethingAgain = now.advanced(by: .seconds(30))
    }

    private func shouldSayUser(user: String, now: ContinuousClock.Instant) -> Bool {
        if user != latestUserThatSaidSomething {
            return true
        }
        if now > sayLatestUserThatSaidSomethingAgain {
            return true
        }
        return false
    }
}

extension ChatTextToSpeech: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_: AVSpeechSynthesizer, didFinish _: AVSpeechUtterance) {
        textToSpeechDispatchQueue.async {
            self.currentlyPlayingMessage = nil
            self.trySayNextMessage()
        }
    }
}
