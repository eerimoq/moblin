import AVFAudio
import SwiftUI

struct ChatTextToSpeechSettingsView: View {
    @EnvironmentObject var model: Model
    @State var rate: Float
    @State var volume: Float

    private func onVoiceChange(languageCode: String, voice: String) {
        model.database.chat.textToSpeechLanguageVoices![languageCode] = voice
        model.chatTextToSpeech.setVoices(voices: model.database.chat.textToSpeechLanguageVoices!)
    }

    var body: some View {
        Form {
            Section {
                NavigationLink(destination: VoicesView(
                    textToSpeechLanguageVoices: model.database.chat.textToSpeechLanguageVoices!,
                    onVoiceChange: onVoiceChange
                )) {
                    Text("Voices")
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
                            model.chatTextToSpeech.setRate(rate: rate)
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
                            model.chatTextToSpeech.setVolume(volume: volume)
                        }
                    )
                    Image(systemName: "volume.3.fill")
                }
            }
            Section {
                Toggle(isOn: Binding(get: {
                    model.database.chat.textToSpeechDetectLanguagePerMessage!
                }, set: { value in
                    model.database.chat.textToSpeechDetectLanguagePerMessage = value
                    model.chatTextToSpeech.setDetectLanguagePerMessage(value: value)
                })) {
                    Text("Detect language per message")
                }
                Toggle(isOn: Binding(get: {
                    model.database.chat.textToSpeechSayUsername!
                }, set: { value in
                    model.database.chat.textToSpeechSayUsername = value
                    model.chatTextToSpeech.setSayUsername(value: value)
                })) {
                    Text("Say username")
                }
                Toggle(isOn: Binding(get: {
                    model.database.chat.textToSpeechSubscribersOnly!
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
                    model.database.chat.textToSpeechFilter!
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
                    model.database.chat.textToSpeechFilterMentions!
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
        .toolbar {
            SettingsToolbar()
        }
    }
}
