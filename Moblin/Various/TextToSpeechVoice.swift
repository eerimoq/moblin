import AVFAudio

enum TextToSpeechVoice {
    case apple(voice: AVSpeechSynthesisVoice?)
    case ttsMonster(voiceId: String)
    case elevenLabs(voiceId: String)

    static func find(voices: [String: SettingsVoice], language: String) -> TextToSpeechVoice? {
        let voice = voices[language]
        if voice?.type == .apple, let voiceIdentifier = voice?.apple.voice {
            return .apple(voice: AVSpeechSynthesisVoice(identifier: voiceIdentifier))
        } else if voice?.type == .ttsMonster, let voiceId = voice?.ttsMonster.voiceId {
            return .ttsMonster(voiceId: voiceId)
        } else if voice?.type == .elevenLabs, let voiceId = voice?.elevenLabs.voiceId {
            return .elevenLabs(voiceId: voiceId)
        } else if let voice = AVSpeechSynthesisVoice.speechVoices()
            .filter({ $0.language.starts(with: language) }).first
        {
            return .apple(voice: AVSpeechSynthesisVoice(identifier: voice.identifier))
        }
        return nil
    }
}
