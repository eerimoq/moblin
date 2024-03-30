import AVFAudio
import SwiftUI

private func localize(_ languageCode: String) -> String {
    return NSLocale.current.localizedString(forLanguageCode: languageCode) ?? languageCode
}

private func flag(country: String) -> String {
    let base: UInt32 = 127_397
    var emote = ""
    for ch in country.unicodeScalars {
        emote.unicodeScalars.append(UnicodeScalar(base + ch.value)!)
    }

    return emote
}

private struct LanguageView: View {
    @EnvironmentObject var model: Model
    var languageCode: String
    @State var voice: String

    private func voices(language: String) -> [AVSpeechSynthesisVoice] {
        return AVSpeechSynthesisVoice.speechVoices().filter { $0.language.prefix(2) == language }
    }

    var body: some View {
        Form {
            Picker("", selection: $voice) {
                ForEach(voices(language: languageCode), id: \.identifier) { voice in
                    let emote = flag(country: Locale(identifier: voice.language).region?.identifier ?? "")
                    Text("\(emote) \(voice.name)")
                        .tag(voice.identifier)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
            .onChange(of: voice) { _ in
                model.database.chat.textToSpeechLanguageVoices![languageCode] = voice
                model.store()
                model.setTextToSpeechVoices(voices: model.database.chat.textToSpeechLanguageVoices!)
            }
        }
        .navigationTitle(localize(languageCode))
        .toolbar {
            SettingsToolbar()
        }
    }
}

private struct Language {
    let name: String
    let code: String
    let selectedVoiceIdentifier: String
    let selectedVoiceName: String
}

private struct VoicesView: View {
    @EnvironmentObject var model: Model

    private func languages() -> [Language] {
        var languages: [Language] = []
        var seen: Set<String> = []
        let voices = AVSpeechSynthesisVoice.speechVoices()
        for voice in voices {
            let code = String(voice.language.prefix(2))
            guard !seen.contains(code) else {
                continue
            }
            let selectedVoiceIdentifier = model.database.chat
                .textToSpeechLanguageVoices![code] ?? ""
            let selectedVoiceName = voices.first(where: { $0.identifier == selectedVoiceIdentifier })?
                .name ?? ""
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
                NavigationLink(destination: LanguageView(
                    languageCode: language.code,
                    voice: language.selectedVoiceIdentifier
                )) {
                    HStack {
                        Text(language.name)
                        Spacer()
                        Text(language.selectedVoiceName)
                    }
                }
            }
        }
        .navigationTitle("Voices")
        .toolbar {
            SettingsToolbar()
        }
    }
}

struct ChatTextToSpeechSettingsView: View {
    @EnvironmentObject var model: Model
    @State var rate: Float
    @State var volume: Float

    var body: some View {
        Form {
            Section {
                NavigationLink(destination: VoicesView()) {
                    Text("Voices")
                }
                Toggle(isOn: Binding(get: {
                    model.database.chat.textToSpeechDetectLanguagePerMessage!
                }, set: { value in
                    model.database.chat.textToSpeechDetectLanguagePerMessage = value
                    model.store()
                })) {
                    Text("Detect language per message")
                }
                Toggle(isOn: Binding(get: {
                    model.database.chat.textToSpeechSayUsername!
                }, set: { value in
                    model.database.chat.textToSpeechSayUsername = value
                    model.store()
                })) {
                    Text("Say username")
                }
                Toggle(isOn: Binding(get: {
                    model.database.chat.textToSpeechSubscribersOnly!
                }, set: { value in
                    model.database.chat.textToSpeechSubscribersOnly = value
                    model.store()
                })) {
                    Text("Subscribers only")
                }
                HStack {
                    Image(systemName: "tortoise.fill")
                    Slider(
                        value: $rate,
                        in: 0.3 ... 0.6,
                        step: 0.01,
                        onEditingChanged: { begin in
                            guard !begin else {
                                return
                            }
                            model.database.chat.textToSpeechRate = rate
                            model.store()
                            model.setTextToSpeechRate(rate: rate)
                        }
                    )
                    Image(systemName: "hare.fill")
                }
                HStack {
                    Image(systemName: "volume.1.fill")
                    Slider(
                        value: $volume,
                        in: 0.3 ... 1.0,
                        step: 0.01,
                        onEditingChanged: { begin in
                            guard !begin else {
                                return
                            }
                            model.database.chat.textToSpeechSayVolume = volume
                            model.store()
                            model.setTextToSpeechVolume(volume: volume)
                        }
                    )
                    Image(systemName: "volume.3.fill")
                }
            } footer: {
                Text("Subscribers only is only available for Twitch.")
            }
        }
        .onAppear {
            if #available(iOS 17.0, *) {
                AVSpeechSynthesizer.requestPersonalVoiceAuthorization { _ in
                }
            }
        }
        .navigationTitle("Text to speech")
        .toolbar {
            SettingsToolbar()
        }
    }
}
