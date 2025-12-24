import AVFAudio
import SwiftUI

struct TtsMonsterSettingsView: View {
    @ObservedObject var ttsMonster: SettingsTtsMonster

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    TextEditNavigationView(title: String(localized: "API token"),
                                           value: ttsMonster.apiToken,
                                           onSubmit: { value in
                                               ttsMonster.apiToken = value
                                           },
                                           sensitive: true)
                }
            }
            .navigationTitle("TTS.Monster")
        } label: {
            TtsMonsterLogoAndNameView()
        }
    }
}

func textToSpeechLocalize(_ languageCode: String) -> String {
    return NSLocale.current.localizedString(forLanguageCode: languageCode) ?? languageCode
}

struct TextToSpeechLanguage {
    let name: String
    let code: String
}

func textToSpeechLanguages(appleVoices: [AVSpeechSynthesisVoice]) -> [TextToSpeechLanguage] {
    var languages: [TextToSpeechLanguage] = []
    var seen: Set<String> = []
    for voice in appleVoices {
        let code = String(voice.language.prefix(2))
        guard !seen.contains(code) else {
            continue
        }
        languages.append(TextToSpeechLanguage(name: textToSpeechLocalize(voice.language), code: code))
        seen.insert(code)
    }
    return languages
}

struct ChatTextToSpeechSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var chat: SettingsChat
    @ObservedObject var ttsMonster: SettingsTtsMonster
    @State private var appleVoices: [AVSpeechSynthesisVoice] = []

    private func onVoiceChange(languageCode: String, voice: SettingsVoice) {
        chat.textToSpeechLanguageVoices[languageCode] = voice
        model.chatTextToSpeech.setVoices(voices: chat.textToSpeechLanguageVoices)
    }

    private func onLanguageReset(languageCode: String) {
        chat.textToSpeechLanguageVoices.removeValue(forKey: languageCode)
        model.chatTextToSpeech.setVoices(voices: chat.textToSpeechLanguageVoices)
    }

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    VoicesView(
                        textToSpeechLanguageVoices: $chat.textToSpeechLanguageVoices,
                        onVoiceChange: onVoiceChange,
                        onLanguageReset: onLanguageReset,
                        rate: $chat.textToSpeechRate,
                        volume: $chat.textToSpeechSayVolume,
                        ttsMonsterApiToken: ttsMonster.apiToken
                    )
                } label: {
                    Text("Voices")
                }
                HStack {
                    Image(systemName: "volume.1.fill")
                    Slider(
                        value: $chat.textToSpeechSayVolume,
                        in: 0.3 ... 1.0,
                        step: 0.01,
                        onEditingChanged: { begin in
                            guard !begin else {
                                return
                            }
                            model.chatTextToSpeech.setVolume(volume: chat.textToSpeechSayVolume)
                        }
                    )
                    Image(systemName: "volume.3.fill")
                }
                HStack {
                    Image(systemName: "tortoise.fill")
                    Slider(
                        value: $chat.textToSpeechRate,
                        in: 0.3 ... 0.6,
                        step: 0.01,
                        onEditingChanged: { begin in
                            guard !begin else {
                                return
                            }
                            model.chatTextToSpeech.setRate(rate: chat.textToSpeechRate)
                        }
                    )
                    Image(systemName: "hare.fill")
                }
                TtsMonsterSettingsView(ttsMonster: chat.ttsMonster)
                    .onChange(of: ttsMonster.apiToken) { _ in
                        model.chatTextToSpeech.setTtsMonsterApiToken(apiToken: ttsMonster.apiToken)
                    }
            } header: {
                Text("Voice")
            }
            Section {
                HStack {
                    Slider(
                        value: $chat.textToSpeechPauseBetweenMessages,
                        in: 0.5 ... 15.0,
                        step: 0.5,
                        label: {
                            EmptyView()
                        },
                        onEditingChanged: { begin in
                            guard !begin else {
                                return
                            }
                            model.chatTextToSpeech
                                .setPauseBetweenMessages(value: chat.textToSpeechPauseBetweenMessages)
                        }
                    )
                    Text("\(formatOneDecimal(Float(chat.textToSpeechPauseBetweenMessages))) s")
                        .frame(width: 45)
                }
            } header: {
                Text("Pause between messages")
            }
            Section {
                Picker("Default language", selection: $chat.textToSpeechDefaultLanguage) {
                    Text("App language")
                        .tag(nil as String?)
                    ForEach(textToSpeechLanguages(appleVoices: appleVoices), id: \.code) {
                        Text($0.name)
                            .tag($0.code as String?)
                    }
                }
                .onChange(of: chat.textToSpeechDefaultLanguage) {
                    model.chatTextToSpeech.setDefaultLanguage(value: $0)
                }
                Toggle("Detect language per message", isOn: $chat.textToSpeechDetectLanguagePerMessage)
                    .onChange(of: chat.textToSpeechDetectLanguagePerMessage) {
                        model.chatTextToSpeech.setDetectLanguagePerMessage(value: $0)
                    }
                Toggle("Say username", isOn: $chat.textToSpeechSayUsername)
                    .onChange(of: chat.textToSpeechSayUsername) {
                        model.chatTextToSpeech.setSayUsername(value: $0)
                    }
                Toggle("Subscribers only", isOn: $chat.textToSpeechSubscribersOnly)
            } footer: {
                Text("Subscribers only is not available for all platforms.")
            }
            Section {
                Toggle("Filter", isOn: $chat.textToSpeechFilter)
                    .onChange(of: chat.textToSpeechFilter) { value in
                        model.chatTextToSpeech.setFilter(value: value)
                    }
            } footer: {
                Text("Do not say messages that are likely spam or bot commands.")
            }
            Section {
                Toggle("Filter mentions", isOn: $chat.textToSpeechFilterMentions)
                    .onChange(of: chat.textToSpeechFilterMentions) { value in
                        model.chatTextToSpeech.setFilterMentions(value: value)
                    }
            } footer: {
                Text("Do not say messages that contains mentions, except when you are mentioned.")
            }
        }
        .onAppear {
            appleVoices = AVSpeechSynthesisVoice.speechVoices()
            if #available(iOS 17.0, *) {
                AVSpeechSynthesizer.requestPersonalVoiceAuthorization { _ in
                }
            }
        }
        .navigationTitle("Text to speech")
    }
}
