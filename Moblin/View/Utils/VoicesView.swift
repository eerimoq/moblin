import AVFAudio
import SwiftUI

private func localize(_ languageCode: String) -> String {
    return NSLocale.current.localizedString(forLanguageCode: languageCode) ?? languageCode
}

private let testMessageByLanguage = [
    "ar": "هذا ما يتحدث عنه جمهورك! استمع بعناية!",
    "bg": "Това говорят вашите зрители! Слушайте внимателно!",
    "ca": "Això són els teus espectadors! Escolta atentament!",
    "cs": "Tohle mluví vaši diváci! Poslouchejte pozorně!",
    "da": "Det er dine seere, der taler! Lyt godt efter!",
    "de": "Hier sprechen Ihre Zuschauer! Hören Sie gut zu!",
    "en": "This is your chat speaking! Listen carefully!",
    "el": "Αυτοί είναι οι θεατές σας που μιλάνε! Ακούστε προσεκτικά!",
    "es": "¡Les habla la audiencia! ¡Escuchen atentamente!",
    "fi": "Katsojasi puhuvat! Kuuntele tarkkaan!",
    "fr": "Ce sont vos spectateurs qui parlent! Écoutez attentivement!",
    "he": "אלו הצופים שלכם שמדברים! תקשיבו היטב!",
    "hi": "ये आपके दर्शक बोल रहे हैं! ध्यान से सुनिए!",
    "hr": "Ovo govore vaši gledatelji! Slušajte pažljivo!",
    "hu": "Itt a nézőid beszélnek! Figyeljetek jól!",
    "id": "Ini pemirsa Anda yang berbicara! Dengarkan baik-baik!",
    "it": "Sono i tuoi spettatori a parlare! Ascolta attentamente!",
    "ja": "視聴者の声です！よく聞いてください！",
    "ko": "시청자 여러분의 이야기입니다! 잘 들어보세요!",
    "ms": "Ini adalah penonton anda bercakap! Dengar baik-baik!",
    "nb": "Dette er seerne dine som snakker! Lytt nøye!",
    "nl": "Dit zijn je kijkers die praten! Luister goed!",
    "no": "Dette er seerne dine som snakker! Lytt nøye!",
    "pl": "To mówią Twoi widzowie! Słuchaj uważnie!",
    "pt": "Quem fala aqui são os seus espectadores! Ouçam com atenção!",
    "ro": "Aici vorbesc spectatorii tăi! Ascultați cu atenție!",
    "ru": "Это говорят ваши зрители! Слушайте внимательно!",
    "sk": "Toto hovoria vaši diváci! Počúvajte pozorne!",
    "sl": "To govorijo vaši gledalci! Poslušajte pozorno!",
    "sv": "Det här är dina tittare som pratar! Lyssna noga!",
    "ta": "இது உங்கள் பார்வையாளர்கள் பேசுவது! கவனமாகக் கேளுங்கள்!",
    "th": "นี่คือเสียงผู้ชมของคุณ! ฟังอย่างตั้งใจ!",
    "tr": "İzleyicileriniz konuşuyor! Dikkatlice dinleyin!",
    "uk": "Це говорять ваші глядачі! Слухайте уважно!",
    "vi": "Đây là lời của khán giả! Hãy lắng nghe thật kỹ!",
    "zh": "這是觀眾的發言！仔細聽！",
]

private struct LanguageView: View {
    let languageCode: String
    @State var voice: String
    let onVoiceChange: (String, String) -> Void
    let synthesizer: AVSpeechSynthesizer
    @Binding var rate: Float
    @Binding var volume: Float

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
                            utterance.rate = rate
                            utterance.pitchMultiplier = 0.8
                            utterance.volume = volume
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
    private let synthesizer = createSpeechSynthesizer()
    @Binding var rate: Float
    @Binding var volume: Float

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
                        synthesizer: synthesizer,
                        rate: $rate,
                        volume: $volume
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
