import SwiftUI

struct ChatSettingsView: View {
    @EnvironmentObject var model: Model
    @State var timestampColor: Color
    @State var usernameColor: Color
    @State var messageColor: Color
    @State var backgroundColor: Color
    @State var shadowColor: Color
    @State var height: Double
    @State var width: Double
    @State var fontSize: Float

    func submitMaximumAge(value: String) {
        guard let maximumAge = Int(value) else {
            return
        }
        guard maximumAge > 0 else {
            return
        }
        model.database.chat.maximumAge = maximumAge
        model.store()
    }

    var body: some View {
        Form {
            Section {
                Toggle("Enabled", isOn: Binding(get: {
                    model.database.chat.enabled!
                }, set: { value in
                    model.database.chat.enabled = value
                    model.store()
                    model.reloadChats()
                }))
            }
            Section {
                HStack {
                    Text("Font size")
                    Slider(
                        value: $fontSize,
                        in: 10 ... 30,
                        step: 1,
                        onEditingChanged: { begin in
                            guard !begin else {
                                return
                            }
                            model.database.chat.fontSize = fontSize
                            model.store()
                            model.reloadChatMessages()
                        }
                    )
                    .onChange(of: fontSize) { value in
                        model.database.chat.fontSize = value
                        model.reloadChatMessages()
                    }
                    Text(String(Int(fontSize)))
                        .frame(width: 25)
                }
                if model.database.showAllSettings! {
                    Toggle(isOn: Binding(get: {
                        model.database.chat.timestampColorEnabled
                    }, set: { value in
                        model.database.chat.timestampColorEnabled = value
                        model.store()
                        model.reloadChatMessages()
                    })) {
                        Text("Timestamp")
                    }
                    Toggle(isOn: Binding(get: {
                        model.database.chat.boldUsername
                    }, set: { value in
                        model.database.chat.boldUsername = value
                        model.store()
                        model.reloadChatMessages()
                    })) {
                        Text("Bold username")
                    }
                    Toggle(isOn: Binding(get: {
                        model.database.chat.boldMessage
                    }, set: { value in
                        model.database.chat.boldMessage = value
                        model.store()
                        model.reloadChatMessages()
                    })) {
                        Text("Bold message")
                    }
                    Toggle(isOn: Binding(get: {
                        model.database.chat.animatedEmotes
                    }, set: { value in
                        model.database.chat.animatedEmotes = value
                        model.store()
                        model.reloadChatMessages()
                    })) {
                        Text("Animated emotes")
                    }
                    NavigationLink(destination: TextEditView(
                        title: String(localized: "Maximum age"),
                        value: String(model.database.chat.maximumAge!),
                        onSubmit: submitMaximumAge,
                        footers: [String(localized: "Maximum message age in seconds.")]
                    )) {
                        Toggle(isOn: Binding(get: {
                            model.database.chat.maximumAgeEnabled!
                        }, set: { value in
                            model.database.chat.maximumAgeEnabled = value
                            model.store()
                        })) {
                            TextItemView(
                                name: String(localized: "Maximum age"),
                                value: String(model.database.chat.maximumAge!)
                            )
                        }
                    }
                }
                NavigationLink(destination: ChatUsernamesToIgnoreSettingsView()) {
                    Text("Usernames to ignore")
                }
                NavigationLink(destination: ChatTextToSpeechSettingsView(
                    rate: model.database.chat.textToSpeechRate!,
                    volume: model.database.chat.textToSpeechSayVolume!
                )) {
                    Toggle(isOn: Binding(get: {
                        model.database.chat.textToSpeechEnabled!
                    }, set: { value in
                        model.database.chat.textToSpeechEnabled = value
                        model.store()
                        if !value {
                            model.chatTextToSpeech.reset(running: true)
                        }
                    })) {
                        Text("Text to speech")
                    }
                }
                NavigationLink(destination: ChatBotSettingsView()) {
                    Toggle(isOn: Binding(get: {
                        model.database.chat.botEnabled!
                    }, set: { value in
                        model.database.chat.botEnabled = value
                        model.store()
                    })) {
                        Text("Bot")
                    }
                }
                if model.database.showAllSettings! {
                    Toggle(isOn: Binding(get: {
                        model.database.chat.mirrored!
                    }, set: { value in
                        model.database.chat.mirrored = value
                        model.store()
                        model.objectWillChange.send()
                    })) {
                        Text("Mirrored")
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
                        value: $height,
                        in: 0.2 ... 1.0,
                        step: 0.05,
                        onEditingChanged: { begin in
                            guard !begin else {
                                return
                            }
                            model.database.chat.height = height
                            model.store()
                            model.reloadChatMessages()
                        }
                    )
                    .onChange(of: height) { value in
                        model.database.chat.height = value
                    }
                    Text("\(Int(100 * height)) %")
                        .frame(width: 55)
                }
                HStack {
                    Text("Width")
                    Slider(
                        value: $width,
                        in: 0.2 ... 1.0,
                        step: 0.05,
                        onEditingChanged: { begin in
                            guard !begin else {
                                return
                            }
                            model.database.chat.width = width
                            model.store()
                            model.reloadChatMessages()
                        }
                    )
                    .onChange(of: width) { value in
                        model.database.chat.width = value
                    }
                    Text("\(Int(100 * width)) %")
                        .frame(width: 55)
                }
            }
            if model.database.showAllSettings! {
                Section {
                    ColorPicker("Timestamp", selection: $timestampColor, supportsOpacity: false)
                        .onChange(of: timestampColor) { _ in
                            guard let color = timestampColor.toRgb() else {
                                return
                            }
                            model.database.chat.timestampColor = color
                            model.reloadChatMessages()
                        }
                    ColorPicker("Username", selection: $usernameColor, supportsOpacity: false)
                        .onChange(of: usernameColor) { _ in
                            guard let color = usernameColor.toRgb() else {
                                return
                            }
                            model.database.chat.usernameColor = color
                            model.reloadChatMessages()
                        }
                    ColorPicker("Message", selection: $messageColor, supportsOpacity: false)
                        .onChange(of: messageColor) { _ in
                            guard let color = messageColor.toRgb() else {
                                return
                            }
                            model.database.chat.messageColor = color
                            model.reloadChatMessages()
                        }
                    Toggle(isOn: Binding(get: {
                        model.database.chat.backgroundColorEnabled
                    }, set: { value in
                        model.database.chat.backgroundColorEnabled = value
                        model.store()
                        model.reloadChatMessages()
                    })) {
                        ColorPicker("Background", selection: $backgroundColor, supportsOpacity: false)
                            .onChange(of: backgroundColor) { _ in
                                guard let color = backgroundColor.toRgb() else {
                                    return
                                }
                                model.database.chat.backgroundColor = color
                                model.reloadChatMessages()
                            }
                    }
                    Toggle(isOn: Binding(get: {
                        model.database.chat.shadowColorEnabled
                    }, set: { value in
                        model.database.chat.shadowColorEnabled = value
                        model.store()
                        model.reloadChatMessages()
                    })) {
                        ColorPicker("Border", selection: $shadowColor, supportsOpacity: false)
                            .onChange(of: shadowColor) { _ in
                                guard let color = shadowColor.toRgb() else {
                                    return
                                }
                                model.database.chat.shadowColor = color
                                model.reloadChatMessages()
                            }
                    }
                    Toggle(isOn: Binding(get: {
                        model.database.chat.meInUsernameColor!
                    }, set: { value in
                        model.database.chat.meInUsernameColor = value
                        model.store()
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
        .onDisappear {
            model.store()
        }
        .navigationTitle("Chat")
        .toolbar {
            SettingsToolbar()
        }
    }
}
