import SwiftUI

struct ChatSettingsView: View {
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
        Form {
            Section {
                Toggle("Enabled", isOn: $chat.enabled)
                    .onChange(of: chat.enabled) { _ in
                        model.reloadChats()
                    }
            }
            Section {
                NavigationLink {
                    Form {
                        StreamPlatformsSettingsView(stream: model.stream)
                    }
                    .navigationTitle("Streaming platforms")
                } label: {
                    Label("Streaming platforms", systemImage: "dot.radiowaves.left.and.right")
                }
            } header: {
                Text("Shortcut")
            }
            Section {
                HStack {
                    Text("Font size")
                    Slider(
                        value: $chat.fontSize,
                        in: 10 ... 30,
                        step: 1,
                        label: {
                            EmptyView()
                        },
                        onEditingChanged: { begin in
                            guard !begin else {
                                return
                            }
                            model.reloadChatMessages()
                        }
                    )
                    .onChange(of: chat.fontSize) { _ in
                        model.reloadChatMessages()
                    }
                    Text(String(Int(chat.fontSize)))
                        .frame(width: 25)
                }
                if model.database.showAllSettings {
                    Toggle("Show deleted messages", isOn: $chat.showDeletedMessages)
                        .onChange(of: chat.showDeletedMessages) { _ in
                            model.reloadChatMessages()
                        }
                    Toggle("Timestamp", isOn: $chat.timestampColorEnabled)
                        .onChange(of: chat.timestampColorEnabled) { _ in
                            model.reloadChatMessages()
                        }
                    Picker("Display style", selection: $chat.displayStyle) {
                        ForEach(SettingsChatDisplayStyle.allCases, id: \.self) { displayStyle in
                            Text(displayStyle.toString())
                        }
                    }
                    Toggle("Bold username", isOn: $chat.boldUsername)
                        .onChange(of: chat.boldUsername) { _ in
                            model.reloadChatMessages()
                        }
                    Toggle("Bold message", isOn: $chat.boldMessage)
                        .onChange(of: chat.boldMessage) { _ in
                            model.reloadChatMessages()
                        }
                    Toggle("Badges", isOn: $chat.badges)
                        .onChange(of: chat.badges) { _ in
                            model.reloadChatMessages()
                        }
                    Toggle("Streaming platform", isOn: $chat.platform)
                        .onChange(of: chat.platform) { _ in
                            model.reloadChatMessages()
                        }
                    Toggle("Animated emotes", isOn: $chat.animatedEmotes)
                        .onChange(of: chat.animatedEmotes) { _ in
                            model.reloadChatMessages()
                        }
                    Toggle("New messages at top", isOn: $chat.newMessagesAtTop)
                    Toggle("Mirrored", isOn: $chat.mirrored)
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
                }
                ChatFiltersSettingsView(chat: chat)
                NavigationLink {
                    ChatTextToSpeechSettingsView(chat: chat)
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
                NavigationLink {
                    ChatBotSettingsView()
                } label: {
                    Toggle(isOn: $chat.botEnabled) {
                        Text("Bot")
                    }
                }
                ChatNicknamesSettingsView(model: model, nicknames: chat.nicknames)
            } header: {
                Text("General")
            } footer: {
                Text(
                    "Animated emotes are fairly CPU intensive. Disable for less power usage."
                )
            }
            Section("Geometry") {
                HStack {
                    Text("Height")
                    Slider(
                        value: $chat.height,
                        in: 0.2 ... 1.0,
                        step: 0.01,
                        onEditingChanged: { begin in
                            guard !begin else {
                                return
                            }
                            model.reloadChatMessages()
                        }
                    )
                    Text("\(Int(100 * chat.height))%")
                        .frame(width: sliderValuePercentageWidth)
                }
                HStack {
                    Text("Width")
                    Slider(
                        value: $chat.width,
                        in: 0.2 ... 1.0,
                        step: 0.01,
                        onEditingChanged: { begin in
                            guard !begin else {
                                return
                            }
                            model.reloadChatMessages()
                        }
                    )
                    Text("\(Int(100 * chat.width))%")
                        .frame(width: sliderValuePercentageWidth)
                }
                HStack {
                    Text("Bottom")
                    Slider(
                        value: $chat.bottomPoints,
                        in: 0.0 ... 200.0,
                        step: 5,
                        onEditingChanged: { begin in
                            guard !begin else {
                                return
                            }
                            model.reloadChatMessages()
                        }
                    )
                    Text("\(Int(chat.bottomPoints)) pts")
                        .frame(width: sliderValuePercentageWidth)
                }
            }
            if model.database.showAllSettings {
                Section {
                    ColorPicker("Timestamp", selection: $chat.timestampColorColor, supportsOpacity: false)
                        .onChange(of: chat.timestampColorColor) { _ in
                            guard let color = chat.timestampColorColor.toRgb() else {
                                return
                            }
                            chat.timestampColor = color
                            model.reloadChatMessages()
                        }
                    ColorPicker("Username", selection: $chat.usernameColorColor, supportsOpacity: false)
                        .onChange(of: chat.usernameColorColor) { _ in
                            guard let color = chat.usernameColorColor.toRgb() else {
                                return
                            }
                            chat.usernameColor = color
                            model.reloadChatMessages()
                        }
                    ColorPicker("Message", selection: $chat.messageColorColor, supportsOpacity: false)
                        .onChange(of: chat.messageColorColor) { _ in
                            guard let color = chat.messageColorColor.toRgb() else {
                                return
                            }
                            chat.messageColor = color
                            model.reloadChatMessages()
                        }
                    Toggle(isOn: $chat.backgroundColorEnabled) {
                        ColorPicker("Background", selection: $chat.backgroundColorColor, supportsOpacity: false)
                            .onChange(of: chat.backgroundColorColor) { _ in
                                guard let color = chat.backgroundColorColor.toRgb() else {
                                    return
                                }
                                chat.backgroundColor = color
                                model.reloadChatMessages()
                            }
                    }
                    .onChange(of: chat.backgroundColorEnabled) { _ in
                        model.reloadChatMessages()
                    }
                    Toggle(isOn: $chat.shadowColorEnabled) {
                        ColorPicker("Border", selection: $chat.shadowColorColor, supportsOpacity: false)
                            .onChange(of: chat.shadowColorColor) { _ in
                                guard let color = chat.shadowColorColor.toRgb() else {
                                    return
                                }
                                chat.shadowColor = color
                                model.reloadChatMessages()
                            }
                    }
                    .onChange(of: chat.shadowColorEnabled) { _ in
                        model.reloadChatMessages()
                    }
                    Toggle(isOn: Binding(get: {
                        chat.meInUsernameColor
                    }, set: { value in
                        chat.meInUsernameColor = value
                    })) {
                        Text("Me in username color")
                    }
                } header: {
                    Text("Colors")
                } footer: {
                    Text("Border is fairly CPU intensive. Disable for less power usage.")
                }
            }
        }
        .navigationTitle("Chat")
    }
}
