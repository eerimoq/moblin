import AVFAudio
import SwiftUI

private func localize(_ languageCode: String) -> String {
    return NSLocale.current.localizedString(forLanguageCode: languageCode) ?? languageCode
}

private func getVoice(appleVoices: [AVSpeechSynthesisVoice],
                      languageCode: String,
                      identifier: String) -> AVSpeechSynthesisVoice?
{
    return appleVoices.first(where: {
        $0.language.prefix(2) == languageCode && $0.identifier == identifier
    })
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

private func getTestMessage(_ languageCode: String) -> String {
    return testMessageByLanguage[languageCode] ?? ""
}

private enum Voice {
    case apple(name: String, identifier: String)
    case ttsMonster(name: String, voiceId: String)

    init(voice: SettingsVoice) {
        switch voice.type {
        case .apple:
            self = .apple(name: "", identifier: voice.apple.voice)
        case .ttsMonster:
            self = .ttsMonster(name: voice.ttsMonster.name, voiceId: voice.ttsMonster.voiceId)
        }
    }
}

private struct VoicePickerItem: Identifiable, Equatable, Hashable {
    var id: String {
        switch voice {
        case let .apple(_, identifier):
            return "apple:\(identifier)"
        case let .ttsMonster(_, voice_id):
            return "tts-monster:\(voice_id)"
        }
    }

    let flagEmoji: String
    let voice: Voice

    static func == (lhs: VoicePickerItem, rhs: VoicePickerItem) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    func toSettings() -> SettingsVoice {
        let settings = SettingsVoice()
        switch voice {
        case let .apple(_, identifier):
            settings.type = .apple
            settings.apple.voice = identifier
        case let .ttsMonster(name, voiceId):
            settings.type = .ttsMonster
            settings.ttsMonster.name = name
            settings.ttsMonster.voiceId = voiceId
        }
        return settings
    }
}

private struct VoiceView: View {
    let voiceItem: VoicePickerItem
    let appleVoices: [AVSpeechSynthesisVoice]
    let languageCode: String
    let synthesizer: AVSpeechSynthesizer
    @State var audioPlayer: AVAudioPlayer?
    @Binding var rate: Float
    @Binding var volume: Float
    let ttsMonsterApiToken: String
    @State private var fetching: Bool = false

    private func playAppleTestMessage(languageCode: String, identifier: String) {
        let utterance = AVSpeechUtterance(string: getTestMessage(languageCode))
        utterance.rate = rate
        utterance.pitchMultiplier = 0.8
        utterance.volume = volume
        utterance.voice = getVoice(appleVoices: appleVoices,
                                   languageCode: languageCode,
                                   identifier: identifier)
        synthesizer.speak(utterance)
    }

    private func playTtsMonsterTestMessage(voiceId: String) {
        Task { @MainActor in
            guard !ttsMonsterApiToken.isEmpty else {
                return
            }
            fetching = true
            defer {
                fetching = false
            }
            let ttsMonster = TtsMonster(apiToken: ttsMonsterApiToken)
            let message = getTestMessage(languageCode)
            guard let data = await ttsMonster.generateTts(voiceId: voiceId, message: message) else {
                return
            }
            audioPlayer = try? AVAudioPlayer(data: data)
            audioPlayer?.play()
        }
    }

    var body: some View {
        HStack {
            switch voiceItem.voice {
            case let .apple(name: name, identifier: identifier):
                Image(systemName: "apple.logo")
                    .frame(width: 15)
                Text("\(voiceItem.flagEmoji) \(name)")
                Spacer()
                Button {
                    playAppleTestMessage(languageCode: languageCode, identifier: identifier)
                } label: {
                    Image(systemName: "play.fill")
                }
            case let .ttsMonster(name: name, voiceId: voiceId):
                Image("TtsMonster")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 15)
                Text("\(voiceItem.flagEmoji) \(name)")
                Spacer()
                Button {
                    playTtsMonsterTestMessage(voiceId: voiceId)
                } label: {
                    if fetching {
                        ProgressView()
                    } else {
                        Image(systemName: "play.fill")
                    }
                }
            }
        }
    }
}

private struct LanguageView: View {
    let appleVoices: [AVSpeechSynthesisVoice]
    let ttsMonsterVoices: TtsMonsterVoicesResponse?
    let languageCode: String
    @State var selectedVoice: VoicePickerItem?
    let onVoiceChange: (String, SettingsVoice) -> Void
    let synthesizer: AVSpeechSynthesizer
    @Binding var rate: Float
    @Binding var volume: Float
    let ttsMonsterApiToken: String

    private func voices(languageCode: String) -> [VoicePickerItem] {
        var voices: [VoicePickerItem] = []
        for voice in appleVoices where voice.language.prefix(2) == languageCode {
            let flagEmoji = emojiFlag(countryCode: Locale(identifier: voice.language).region?.identifier)
            voices.append(VoicePickerItem(flagEmoji: flagEmoji,
                                          voice: .apple(name: voice.name, identifier: voice.identifier)))
        }
        for voice in ttsMonsterVoices?.allVoices() ?? [] where voice.languageCode() == languageCode {
            let flagEmoji = emojiFlag(countryCode: voice.countryCode())
            voices.append(VoicePickerItem(flagEmoji: flagEmoji,
                                          voice: .ttsMonster(name: voice.name, voiceId: voice.voice_id)))
        }
        return voices
    }

    var body: some View {
        Form {
            Section {
                Picker("", selection: $selectedVoice) {
                    ForEach(voices(languageCode: languageCode)) { voiceItem in
                        VoiceView(
                            voiceItem: voiceItem,
                            appleVoices: appleVoices,
                            languageCode: languageCode,
                            synthesizer: synthesizer,
                            rate: $rate,
                            volume: $volume,
                            ttsMonsterApiToken: ttsMonsterApiToken
                        )
                        .tag(voiceItem as VoicePickerItem?)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
                .onChange(of: selectedVoice) { _ in
                    guard let selectedVoice else {
                        return
                    }
                    onVoiceChange(languageCode, selectedVoice.toSettings())
                }
            }
            Section {
                Text("""
                Download enhanced and premium voices in iOS Settings → Accessibility → \
                Live Speech → Preferred Voices.
                """)
            }
        }
        .navigationTitle(localize(languageCode))
    }
}

private struct Language {
    let name: String
    let code: String
    let selectedVoice: SettingsVoice?
}

struct VoicesView: View {
    @Binding var textToSpeechLanguageVoices: [String: SettingsVoice]
    let onVoiceChange: (String, SettingsVoice) -> Void
    private let synthesizer = createSpeechSynthesizer()
    @Binding var rate: Float
    @Binding var volume: Float
    @State private var appleVoices: [AVSpeechSynthesisVoice] = []
    @State private var ttsMonsterVoices: TtsMonsterVoicesResponse?
    let ttsMonsterApiToken: String

    private func languages() -> [Language] {
        var languages: [Language] = []
        var seen: Set<String> = []
        for voice in appleVoices {
            let code = String(voice.language.prefix(2))
            guard !seen.contains(code) else {
                continue
            }
            languages.append(Language(name: localize(voice.language),
                                      code: code,
                                      selectedVoice: textToSpeechLanguageVoices[code]))
            seen.insert(code)
        }
        return languages
    }

    private func selectedVoice(language: Language) -> VoicePickerItem? {
        guard let selectedVoice = language.selectedVoice else {
            return nil
        }
        return VoicePickerItem(flagEmoji: emojiFlag(countryCode: language.code), voice: Voice(voice: selectedVoice))
    }

    var body: some View {
        Form {
            ForEach(languages(), id: \.code) { language in
                NavigationLink {
                    LanguageView(
                        appleVoices: appleVoices,
                        ttsMonsterVoices: ttsMonsterVoices,
                        languageCode: language.code,
                        selectedVoice: selectedVoice(language: language),
                        onVoiceChange: onVoiceChange,
                        synthesizer: synthesizer,
                        rate: $rate,
                        volume: $volume,
                        ttsMonsterApiToken: ttsMonsterApiToken
                    )
                } label: {
                    HStack {
                        Text(language.name)
                        Spacer()
                        if let selectedVoice = language.selectedVoice {
                            switch selectedVoice.type {
                            case .apple:
                                Image(systemName: "apple.logo")
                                    .frame(width: 15)
                                Text(getVoice(appleVoices: appleVoices,
                                              languageCode: language.code,
                                              identifier: selectedVoice.apple.voice)?
                                        .name ?? String(localized: "Unknown"))
                            case .ttsMonster:
                                Image("TtsMonster")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 15)
                                Text(selectedVoice.ttsMonster.name)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Voices")
        .onAppear {
            appleVoices = AVSpeechSynthesisVoice.speechVoices()
        }
        .task {
            if ttsMonsterVoices == nil, !ttsMonsterApiToken.isEmpty {
                let ttsMonster = TtsMonster(apiToken: ttsMonsterApiToken)
                ttsMonsterVoices = await ttsMonster.getVoices()
            }
        }
    }
}
