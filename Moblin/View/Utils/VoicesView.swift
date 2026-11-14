import AVFAudio
import SwiftUI

private func getVoice(appleVoices: [AVSpeechSynthesisVoice],
                      languageCode: String,
                      identifier: String) -> AVSpeechSynthesisVoice?
{
    appleVoices.first(where: {
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
    testMessageByLanguage[languageCode] ?? ""
}

private enum Voice {
    case apple(name: String, identifier: String)
    case ttsMonster(name: String, voiceId: String)
    case elevenLabs(name: String, voiceId: String)

    init(voice: SettingsVoice) {
        switch voice.type {
        case .apple:
            self = .apple(name: "", identifier: voice.apple.voice)
        case .ttsMonster:
            self = .ttsMonster(name: voice.ttsMonster.name, voiceId: voice.ttsMonster.voiceId)
        case .elevenLabs:
            self = .elevenLabs(name: voice.elevenLabs.name, voiceId: voice.elevenLabs.voiceId)
        }
    }
}

private struct VoicePickerItem: Identifiable, Equatable, Hashable {
    var id: String {
        switch voice {
        case let .apple(_, identifier):
            "apple:\(identifier)"
        case let .ttsMonster(_, voice_id):
            "tts-monster:\(voice_id)"
        case let .elevenLabs(_, voiceId):
            "eleven-labs:\(voiceId)"
        }
    }

    let flagEmoji: String
    let voice: Voice

    static func == (lhs: VoicePickerItem, rhs: VoicePickerItem) -> Bool {
        lhs.id == rhs.id
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
        case let .elevenLabs(name, voiceId):
            settings.type = .elevenLabs
            settings.elevenLabs.name = name
            settings.elevenLabs.voiceId = voiceId
        }
        return settings
    }
}

private struct VoiceView: View {
    let voiceItem: VoicePickerItem
    let appleVoices: [AVSpeechSynthesisVoice]
    let languageCode: String
    let synthesizer: SpeechSynthesizer
    @State var audioPlayer: AudioPlayer?
    @Binding var rate: Float
    @Binding var volume: Float
    let ttsMonsterApiToken: String
    let elevenLabsApiKey: String
    @State private var fetching: Bool = false

    private func playAppleTestMessage(languageCode: String, identifier: String) {
        let utterance = AVSpeechUtterance(string: getTestMessage(languageCode))
        utterance.rate = rate
        utterance.pitchMultiplier = 0.8
        utterance.voice = getVoice(appleVoices: appleVoices,
                                   languageCode: languageCode,
                                   identifier: identifier)
        synthesizer.speak(utterance: utterance, volume: volume)
    }

    private func playTtsMonsterTestMessage(voiceId: String) {
        guard !ttsMonsterApiToken.isEmpty else {
            return
        }
        let apiToken = ttsMonsterApiToken
        playGeneratedTestMessage {
            await TtsMonster(apiToken: apiToken).generateTts(voiceId: voiceId, message: $0)
        }
    }

    private func playElevenLabsTestMessage(voiceId: String) {
        guard !elevenLabsApiKey.isEmpty else {
            return
        }
        let apiKey = elevenLabsApiKey
        playGeneratedTestMessage {
            await ElevenLabs(apiKey: apiKey).generateTts(voiceId: voiceId, message: $0)
        }
    }

    private func playGeneratedTestMessage(generate: @escaping @Sendable (String) async -> Data?) {
        Task {
            fetching = true
            defer {
                fetching = false
            }
            guard let data = await generate(getTestMessage(languageCode)) else {
                return
            }
            audioPlayer = try? AudioPlayer(data: data)
            audioPlayer?.play()
        }
    }

    private func playButton(action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            if fetching {
                ProgressView()
            } else {
                Image(systemName: "play.fill")
            }
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
                    .scaledToFit()
                    .frame(width: 15)
                Text("\(voiceItem.flagEmoji) \(name)")
                Spacer()
                playButton {
                    playTtsMonsterTestMessage(voiceId: voiceId)
                }
            case let .elevenLabs(name: name, voiceId: voiceId):
                Image("ElevenLabs")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 15)
                Text("\(voiceItem.flagEmoji) \(name)")
                Spacer()
                playButton {
                    playElevenLabsTestMessage(voiceId: voiceId)
                }
            }
        }
    }
}

private struct LanguageView: View {
    let appleVoices: [AVSpeechSynthesisVoice]
    let ttsMonsterVoices: TtsMonsterVoicesResponse?
    let elevenLabsVoices: ElevenLabsVoicesResponse?
    let languageCode: String
    @State var selectedVoice: VoicePickerItem?
    let onVoiceChange: (String, SettingsVoice) -> Void
    let onLanguageReset: (String) -> Void
    let synthesizer: SpeechSynthesizer
    @Binding var rate: Float
    @Binding var volume: Float
    let ttsMonsterApiToken: String
    let elevenLabsApiKey: String

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
        for voice in elevenLabsVoices?.voices ?? [] {
            let flagEmoji = emojiFlag(countryCode: voice.countryCode(languageCode: languageCode))
            voices.append(VoicePickerItem(flagEmoji: flagEmoji,
                                          voice: .elevenLabs(name: voice.name, voiceId: voice.voice_id)))
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
                            ttsMonsterApiToken: ttsMonsterApiToken,
                            elevenLabsApiKey: elevenLabsApiKey
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
            Section {
                TextButtonView("Reset") {
                    selectedVoice = nil
                    onLanguageReset(languageCode)
                }
            }
        }
        .navigationTitle(textToSpeechLocalize(languageCode))
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
    let onLanguageReset: (String) -> Void
    private let synthesizer = SpeechSynthesizer(queue: .main)
    @Binding var rate: Float
    @Binding var volume: Float
    @State private var appleVoices: [AVSpeechSynthesisVoice] = []
    @State private var ttsMonsterVoices: TtsMonsterVoicesResponse?
    @State private var elevenLabsVoices: ElevenLabsVoicesResponse?
    let ttsMonsterApiToken: String
    let elevenLabsApiKey: String

    private func languages() -> [Language] {
        textToSpeechLanguages(appleVoices: appleVoices).map {
            Language(name: $0.name,
                     code: $0.code,
                     selectedVoice: textToSpeechLanguageVoices[$0.code])
        }
    }

    private func selectedVoice(language: Language) -> VoicePickerItem? {
        guard let selectedVoice = language.selectedVoice else {
            return nil
        }
        return VoicePickerItem(
            flagEmoji: emojiFlag(countryCode: language.code),
            voice: Voice(voice: selectedVoice)
        )
    }

    var body: some View {
        Form {
            ForEach(languages(), id: \.code) { language in
                NavigationLink {
                    LanguageView(
                        appleVoices: appleVoices,
                        ttsMonsterVoices: ttsMonsterVoices,
                        elevenLabsVoices: elevenLabsVoices,
                        languageCode: language.code,
                        selectedVoice: selectedVoice(language: language),
                        onVoiceChange: onVoiceChange,
                        onLanguageReset: onLanguageReset,
                        synthesizer: synthesizer,
                        rate: $rate,
                        volume: $volume,
                        ttsMonsterApiToken: ttsMonsterApiToken,
                        elevenLabsApiKey: elevenLabsApiKey
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
                                    .scaledToFit()
                                    .frame(width: 15)
                                Text(selectedVoice.ttsMonster.name)
                            case .elevenLabs:
                                Image("ElevenLabs")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 15)
                                Text(selectedVoice.elevenLabs.name)
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
            if elevenLabsVoices == nil, !elevenLabsApiKey.isEmpty {
                elevenLabsVoices = await ElevenLabs(apiKey: elevenLabsApiKey).getVoices()
            }
        }
    }
}
