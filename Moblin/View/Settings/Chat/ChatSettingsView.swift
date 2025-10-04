import SwiftUI

private struct ChatSettingsAppearanceView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var chat: SettingsChat

    var body: some View {
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
                Picker("Display style", selection: $chat.displayStyle) {
                    ForEach(SettingsChatDisplayStyle.allCases, id: \.self) { displayStyle in
                        Text(displayStyle.toString())
                    }
                }
                Toggle(isOn: $chat.timestampColorEnabled) {
                    ColorPicker("Timestamp", selection: $chat.timestampColorColor, supportsOpacity: false)
                        .onChange(of: chat.timestampColorColor) { _ in
                            guard let color = chat.timestampColorColor.toRgb() else {
                                return
                            }
                            chat.timestampColor = color
                            model.reloadChatMessages()
                        }
                }
                .onChange(of: chat.timestampColorEnabled) { _ in
                    model.reloadChatMessages()
                }
                Toggle("Bold name", isOn: $chat.boldUsername)
                    .onChange(of: chat.boldUsername) { _ in
                        model.reloadChatMessages()
                    }
                ColorPicker("Name color", selection: $chat.usernameColorColor, supportsOpacity: false)
                    .onChange(of: chat.usernameColorColor) { _ in
                        guard let color = chat.usernameColorColor.toRgb() else {
                            return
                        }
                        chat.usernameColor = color
                        model.reloadChatMessages()
                    }
                Toggle("Bold message", isOn: $chat.boldMessage)
                    .onChange(of: chat.boldMessage) { _ in
                        model.reloadChatMessages()
                    }
                ColorPicker("Message color", selection: $chat.messageColorColor, supportsOpacity: false)
                    .onChange(of: chat.messageColorColor) { _ in
                        guard let color = chat.messageColorColor.toRgb() else {
                            return
                        }
                        chat.messageColor = color
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
                    Text("Me in name color")
                }
                Toggle("New messages at top", isOn: $chat.newMessagesAtTop)
                Toggle("Mirrored", isOn: $chat.mirrored)
            }
        } header: {
            Text("Appearance")
        } footer: {
            if model.database.showAllSettings {
                Text("Animated emotes are fairly CPU intensive. Disable for less power usage.")
            }
        }
    }
}

private struct ChatSettingsGeometryView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var chat: SettingsChat

    var body: some View {
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
    }
}

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
        Section {
            NavigationLink {
                ChatBotSettingsView()
            } label: {
                Toggle(isOn: $chat.botEnabled) {
                    Text("Bot")
                }
            }
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
        } header: {
            Text("General")
        }
    }
}

struct ChatSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var chat: SettingsChat

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
            ChatSettingsAppearanceView(chat: chat)
            ChatSettingsGeometryView(chat: chat)
            ChatSettingsGeneralView(chat: chat)
        }
        .navigationTitle("Chat")
    }
}
