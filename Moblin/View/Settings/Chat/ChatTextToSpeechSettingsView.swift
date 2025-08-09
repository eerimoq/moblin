import AVFAudio
import SwiftUI

struct ChatTextToSpeechSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var chat: SettingsChat

    private func onVoiceChange(languageCode: String, voice: String) {
        chat.textToSpeechLanguageVoices[languageCode] = voice
        model.chatTextToSpeech.setVoices(voices: chat.textToSpeechLanguageVoices)
    }

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    VoicesView(
                        textToSpeechLanguageVoices: $chat.textToSpeechLanguageVoices,
                        onVoiceChange: onVoiceChange,
                        rate: $chat.textToSpeechRate,
                        volume: $chat.textToSpeechSayVolume
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
                Toggle("Detect language per message", isOn: $chat.textToSpeechDetectLanguagePerMessage)
                    .onChange(of: chat.textToSpeechDetectLanguagePerMessage) { value in
                        model.chatTextToSpeech.setDetectLanguagePerMessage(value: value)
                    }
                Toggle("Say username", isOn: $chat.textToSpeechSayUsername)
                    .onChange(of: chat.textToSpeechSayUsername) { value in
                        model.chatTextToSpeech.setSayUsername(value: value)
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
            if #available(iOS 17.0, *) {
                AVSpeechSynthesizer.requestPersonalVoiceAuthorization { _ in
                }
            }
        }
        .navigationTitle("Text to speech")
    }
}
