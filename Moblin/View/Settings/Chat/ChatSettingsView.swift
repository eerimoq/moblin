import SwiftUI

private struct ChatSettingsGeneralView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var chat: SettingsChat

    func submitMaximumAge(value: String) {
        guard let maximumAge = Int(value) else {
            return
        }
        guard maximumAge > 0 else {
            return
        }
        chat.maximumAge = maximumAge
    }

    var body: some View {
        NavigationLink {
            ChatBotSettingsView()
        } label: {
            Toggle(isOn: $chat.botEnabled) {
                Text("Bot")
            }
        }
        NavigationLink {
            ChatTextToSpeechSettingsView(chat: chat, ttsMonster: chat.ttsMonster)
        } label: {
            Toggle(isOn: Binding(get: {
                chat.textToSpeechEnabled
            }, set: { value in
                chat.textToSpeechEnabled = value
                if !value {
                    model.chatTextToSpeech.reset(running: true)
                }
            })) {
                Text("Text to speech")
            }
        }
        if model.database.showAllSettings {
            ChatFiltersSettingsView(chat: chat)
            ChatNicknamesSettingsView(model: model, nicknames: chat.nicknames)
            NavigationLink {
                TextEditView(
                    title: String(localized: "Maximum age"),
                    value: String(chat.maximumAge),
                    footers: [String(localized: "Maximum message age in seconds.")]
                ) {
                    submitMaximumAge(value: $0)
                }
            } label: {
                Toggle(isOn: $chat.maximumAgeEnabled) {
                    TextItemView(
                        name: String(localized: "Maximum age"),
                        value: String(chat.maximumAge)
                    )
                }
            }
            Toggle("Show deleted messages", isOn: $chat.showDeletedMessages)
                .onChange(of: chat.showDeletedMessages) { _ in
                    model.reloadChatMessages()
                }
        }
    }
}

struct ChatSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var chat: SettingsChat
    @ObservedObject var stream: SettingsStream

    var body: some View {
        Form {
            Section {
                Toggle("Enabled", isOn: $chat.enabled)
                    .onChange(of: chat.enabled) { _ in
                        model.reloadChats()
                    }
            }
            Section {
                ChatSettingsAppearanceView(chat: chat)
                ChatSettingsLayoutView(chat: chat)
                ChatSettingsGeneralView(chat: chat)
            }
            if stream !== fallbackStream {
                Section {
                    NavigationLink {
                        Form {
                            StreamPlatformsSettingsView(stream: stream)
                        }
                        .navigationTitle("Streaming platforms")
                    } label: {
                        Label("Streaming platforms", systemImage: "dot.radiowaves.left.and.right")
                    }
                    NavigationLink {
                        StreamEmotesSettingsView(stream: stream)
                    } label: {
                        Label("Emotes", systemImage: "dot.radiowaves.left.and.right")
                    }
                } header: {
                    Text("Shortcut")
                }
            }
        }
        .navigationTitle("Chat")
    }
}
