import AVFAudio
import SwiftUI

private func localize(_ languageCode: String) -> String {
    return NSLocale.current.localizedString(forLanguageCode: languageCode) ?? languageCode
}

private let testMessageByLanguage = [
    "en": "This is your chat speaking! Listen carefully!",
    "sv": "Det här är dina tittare som pratar! Lyssna noga!",
    "no": "Dette er seerne dine som snakker! Lytt nøye!",
    "es": "¡Les habla la audiencia! ¡Escuchen atentamente!",
    "de": "Hier sprechen Ihre Zuschauer! Hören Sie gut zu!",
    "fr": "Ce sont vos spectateurs qui parlent! Écoutez attentivement!",
    "pl": "To mówią Twoi widzowie! Słuchaj uważnie!",
    "vi": "Đây là lời của khán giả! Hãy lắng nghe thật kỹ!",
    "nl": "Dit zijn je kijkers die praten! Luister goed!",
    "zh": "這是觀眾的發言！仔細聽！",
    "ko": "시청자 여러분의 이야기입니다! 잘 들어보세요!",
    "ru": "Это говорят ваши зрители! Слушайте внимательно!",
    "uk": "Це говорять ваші глядачі! Слухайте уважно!",
    "it": "Sono i tuoi spettatori a parlare! Ascolta attentamente!",
    "ja": "視聴者の声です！よく聞いてください！",
]

private struct LanguageView: View {
    let languageCode: String
    @State var voice: String
    let onVoiceChange: (String, String) -> Void
    let synthesizer: AVSpeechSynthesizer

    private func voices(language: String) -> [AVSpeechSynthesisVoice] {
        return AVSpeechSynthesisVoice.speechVoices().filter { $0.language.prefix(2) == language }
    }

    var body: some View {
        Form {
            Picker("", selection: $voice) {
                ForEach(voices(language: languageCode), id: \.identifier) { voice in
                    let emote = emojiFlag(country: Locale(identifier: voice.language).region?.identifier ?? "")
                    HStack {
                        Text("\(emote) \(voice.name)")
                            .tag(voice.identifier)
                        Spacer()
                        Button {
                            let utterance = AVSpeechUtterance(string: testMessageByLanguage[languageCode] ?? "")
                            utterance.rate = 0.4
                            utterance.pitchMultiplier = 0.8
                            utterance.volume = 1.0
                            utterance.voice = voice
                            synthesizer.speak(utterance)
                        } label: {
                            Image(systemName: "play.fill")
                        }
                    }
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
            .onChange(of: voice) { _ in
                onVoiceChange(languageCode, voice)
            }
        }
        .navigationTitle(localize(languageCode))
    }
}

private struct Language {
    let name: String
    let code: String
    let selectedVoiceIdentifier: String
    let selectedVoiceName: String
}

struct VoicesView: View {
    @Binding var textToSpeechLanguageVoices: [String: String]
    let onVoiceChange: (String, String) -> Void
    private let synthesizer = AVSpeechSynthesizer()

    private func languages() -> [Language] {
        var languages: [Language] = []
        var seen: Set<String> = []
        let voices = AVSpeechSynthesisVoice.speechVoices()
        for voice in voices {
            let code = String(voice.language.prefix(2))
            guard !seen.contains(code) else {
                continue
            }
            let selectedVoiceIdentifier = textToSpeechLanguageVoices[code] ?? ""
            let selectedVoiceName = voices.first(where: { $0.identifier == selectedVoiceIdentifier })?.name ?? ""
            languages.append(.init(name: localize(voice.language),
                                   code: code,
                                   selectedVoiceIdentifier: selectedVoiceIdentifier,
                                   selectedVoiceName: selectedVoiceName))
            seen.insert(code)
        }
        return languages
    }

    var body: some View {
        Form {
            ForEach(languages(), id: \.code) { language in
                NavigationLink {
                    LanguageView(
                        languageCode: language.code,
                        voice: language.selectedVoiceIdentifier,
                        onVoiceChange: onVoiceChange,
                        synthesizer: synthesizer
                    )
                } label: {
                    HStack {
                        Text(language.name)
                        Spacer()
                        Text(language.selectedVoiceName)
                    }
                }
            }
        }
        .navigationTitle("Voices")
    }
}
