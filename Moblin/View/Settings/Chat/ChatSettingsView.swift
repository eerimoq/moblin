import SwiftUI

struct ChatSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var chat: SettingsChat
    @State var timestampColor: Color
    @State var usernameColor: Color
    @State var messageColor: Color
    @State var backgroundColor: Color
    @State var shadowColor: Color

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
                Toggle("Enabled", isOn: Binding(get: {
                    chat.enabled
                }, set: { value in
                    chat.enabled = value
                    model.reloadChats()
                    model.objectWillChange.send()
                }))
            }
            if let stream = model.findStream(id: model.currentStreamId) {
                Section {
                    NavigationLink {
                        Form {
                            StreamPlatformsSettingsView(stream: stream)
                        }
                        .navigationTitle("Streaming platforms")
                    } label: {
                        IconAndTextView(
                            image: "dot.radiowaves.left.and.right",
                            text: String(localized: "Streaming platforms")
                        )
                    }
                } header: {
                    Text("Shortcut")
                }
            }
            Section {
                HStack {
                    Text("Font size")
                    Slider(
                        value: $chat.fontSize,
                        in: 10 ... 30,
                        step: 1,
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
                    Toggle(isOn: Binding(get: {
                        chat.timestampColorEnabled
                    }, set: { value in
                        chat.timestampColorEnabled = value
                        model.reloadChatMessages()
                    })) {
                        Text("Timestamp")
                    }
                    Toggle(isOn: Binding(get: {
                        chat.boldUsername
                    }, set: { value in
                        chat.boldUsername = value
                        model.reloadChatMessages()
                    })) {
                        Text("Bold username")
                    }
                    Toggle(isOn: Binding(get: {
                        chat.boldMessage
                    }, set: { value in
                        chat.boldMessage = value
                        model.reloadChatMessages()
                    })) {
                        Text("Bold message")
                    }
                    Toggle(isOn: Binding(get: {
                        chat.badges
                    }, set: { value in
                        chat.badges = value
                        model.reloadChatMessages()
                    })) {
                        Text("Badges")
                    }
                    Toggle(isOn: Binding(get: {
                        chat.animatedEmotes
                    }, set: { value in
                        chat.animatedEmotes = value
                        model.reloadChatMessages()
                    })) {
                        Text("Animated emotes")
                    }
                    Toggle(isOn: Binding(get: {
                        chat.newMessagesAtTop
                    }, set: { value in
                        chat.newMessagesAtTop = value
                        model.objectWillChange.send()
                    })) {
                        Text("New messages at top")
                    }
                    Toggle(isOn: Binding(get: {
                        chat.mirrored
                    }, set: { value in
                        chat.mirrored = value
                        model.objectWillChange.send()
                    })) {
                        Text("Mirrored")
                    }
                    NavigationLink {
                        TextEditView(
                            title: String(localized: "Maximum age"),
                            value: String(chat.maximumAge),
                            footers: [String(localized: "Maximum message age in seconds.")]
                        ) {
                            submitMaximumAge(value: $0)
                        }
                    } label: {
                        Toggle(isOn: Binding(get: {
                            chat.maximumAgeEnabled
                        }, set: { value in
                            chat.maximumAgeEnabled = value
                        })) {
                            TextItemView(
                                name: String(localized: "Maximum age"),
                                value: String(chat.maximumAge)
                            )
                        }
                    }
                }
                NavigationLink {
                    ChatUsernamesToIgnoreSettingsView()
                } label: {
                    Text("Usernames to ignore")
                }
                NavigationLink {
                    ChatTextToSpeechSettingsView(
                        rate: chat.textToSpeechRate,
                        volume: chat.textToSpeechSayVolume,
                        pauseBetweenMessages: chat.textToSpeechPauseBetweenMessages
                    )
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
                    Toggle(isOn: Binding(get: {
                        chat.botEnabled
                    }, set: { value in
                        chat.botEnabled = value
                    })) {
                        Text("Bot")
                    }
                }
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
                    Text("\(Int(100 * chat.height)) %")
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
                    Text("\(Int(100 * chat.width)) %")
                        .frame(width: sliderValuePercentageWidth)
                }
                HStack {
                    Text("Bottom")
                    Slider(
                        value: $chat.bottom,
                        in: 0.0 ... 0.5,
                        step: 0.01,
                        onEditingChanged: { begin in
                            guard !begin else {
                                return
                            }
                            model.reloadChatMessages()
                        }
                    )
                    Text("\(Int(100 * chat.bottom)) %")
                        .frame(width: sliderValuePercentageWidth)
                }
            }
            if model.database.showAllSettings {
                Section {
                    ColorPicker("Timestamp", selection: $timestampColor, supportsOpacity: false)
                        .onChange(of: timestampColor) { _ in
                            guard let color = timestampColor.toRgb() else {
                                return
                            }
                            chat.timestampColor = color
                            model.reloadChatMessages()
                        }
                    ColorPicker("Username", selection: $usernameColor, supportsOpacity: false)
                        .onChange(of: usernameColor) { _ in
                            guard let color = usernameColor.toRgb() else {
                                return
                            }
                            chat.usernameColor = color
                            model.reloadChatMessages()
                        }
                    ColorPicker("Message", selection: $messageColor, supportsOpacity: false)
                        .onChange(of: messageColor) { _ in
                            guard let color = messageColor.toRgb() else {
                                return
                            }
                            chat.messageColor = color
                            model.reloadChatMessages()
                        }
                    Toggle(isOn: Binding(get: {
                        chat.backgroundColorEnabled
                    }, set: { value in
                        chat.backgroundColorEnabled = value
                        model.reloadChatMessages()
                    })) {
                        ColorPicker("Background", selection: $backgroundColor, supportsOpacity: false)
                            .onChange(of: backgroundColor) { _ in
                                guard let color = backgroundColor.toRgb() else {
                                    return
                                }
                                chat.backgroundColor = color
                                model.reloadChatMessages()
                            }
                    }
                    Toggle(isOn: Binding(get: {
                        chat.shadowColorEnabled
                    }, set: { value in
                        chat.shadowColorEnabled = value
                        model.reloadChatMessages()
                    })) {
                        ColorPicker("Border", selection: $shadowColor, supportsOpacity: false)
                            .onChange(of: shadowColor) { _ in
                                guard let color = shadowColor.toRgb() else {
                                    return
                                }
                                chat.shadowColor = color
                                model.reloadChatMessages()
                            }
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
