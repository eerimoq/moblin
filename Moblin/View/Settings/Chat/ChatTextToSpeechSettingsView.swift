import AVFAudio
import SwiftUI

struct ChatTextToSpeechSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var chat: SettingsChat

    private func onVoiceChange(languageCode: String, voice: String) {
        model.database.chat.textToSpeechLanguageVoices[languageCode] = voice
        model.chatTextToSpeech.setVoices(voices: model.database.chat.textToSpeechLanguageVoices)
    }

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    VoicesView(
                        textToSpeechLanguageVoices: model.database.chat.textToSpeechLanguageVoices,
                        onVoiceChange: onVoiceChange
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
            } header: {
                Text("Voice")
            }
            Section {
                HStack {
                    Slider(
                        value: $chat.textToSpeechPauseBetweenMessages,
                        in: 0.5 ... 15.0,
                        step: 0.5,
                        onEditingChanged: { begin in
                            guard !begin else {
                                return
                            }
                            model.chatTextToSpeech.setPauseBetweenMessages(value: chat.textToSpeechPauseBetweenMessages)
                        }
                    )
                    Text("\(formatOneDecimal(Float(chat.textToSpeechPauseBetweenMessages))) s")
                        .frame(width: 45)
                }
            } header: {
                Text("Pause between messages")
            }
            Section {
                Toggle(isOn: Binding(get: {
                    model.database.chat.textToSpeechDetectLanguagePerMessage
                }, set: { value in
                    model.database.chat.textToSpeechDetectLanguagePerMessage = value
                    model.chatTextToSpeech.setDetectLanguagePerMessage(value: value)
                })) {
                    Text("Detect language per message")
                }
                Toggle(isOn: Binding(get: {
                    model.database.chat.textToSpeechSayUsername
                }, set: { value in
                    model.database.chat.textToSpeechSayUsername = value
                    model.chatTextToSpeech.setSayUsername(value: value)
                })) {
                    Text("Say username")
                }
                Toggle(isOn: Binding(get: {
                    model.database.chat.textToSpeechSubscribersOnly
                }, set: { value in
                    model.database.chat.textToSpeechSubscribersOnly = value
                })) {
                    Text("Subscribers only")
                }
            } footer: {
                Text("Subscribers only is not available for all platforms.")
            }
            Section {
                Toggle(isOn: Binding(get: {
                    model.database.chat.textToSpeechFilter
                }, set: { value in
                    model.database.chat.textToSpeechFilter = value
                    model.chatTextToSpeech.setFilter(value: value)
                })) {
                    Text("Filter")
                }
            } footer: {
                Text("Do not say messages that are likely spam or bot commands.")
            }
            Section {
                Toggle(isOn: Binding(get: {
                    model.database.chat.textToSpeechFilterMentions
                }, set: { value in
                    model.database.chat.textToSpeechFilterMentions = value
                    model.chatTextToSpeech.setFilterMentions(value: value)
                })) {
                    Text("Filter mentions")
                }
            } footer: {
                Text("Do not say messages that contains mentions, except when you are mentioned.")
            }
        }
        .onAppear {
            if #available(iOS 17.0, *) {
                AVSpeechSynthesizer.requestPersonalVoiceAuthorization { _ in
                }
            }
        }
        .navigationTitle("Text to speech")
    }
}
