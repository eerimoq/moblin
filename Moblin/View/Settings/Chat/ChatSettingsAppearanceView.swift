import SwiftUI

struct ChatSettingsAppearanceView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var chat: SettingsChat

    var body: some View {
        NavigationLink {
            Form {
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
                        Toggle("Timestamp", isOn: $chat.timestampColorEnabled)
                            .onChange(of: chat.timestampColorEnabled) { _ in
                                model.reloadChatMessages()
                            }
                        Toggle("Bold name", isOn: $chat.boldUsername)
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
                    }
                } footer: {
                    if model.database.showAllSettings {
                        Text("Animated emotes are fairly CPU intensive. Disable for less power usage.")
                    }
                }
                Section {
                    if model.database.showAllSettings {
                        ColorPicker("Timestamp", selection: $chat.timestampColorColor, supportsOpacity: false)
                            .onChange(of: chat.timestampColorColor) { _ in
                                guard let color = chat.timestampColorColor.toRgb() else {
                                    return
                                }
                                chat.timestampColor = color
                                model.reloadChatMessages()
                            }
                        ColorPicker("Name", selection: $chat.usernameColorColor, supportsOpacity: false)
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
                    if model.database.showAllSettings {
                        Toggle(isOn: Binding(get: {
                            chat.meInUsernameColor
                        }, set: { value in
                            chat.meInUsernameColor = value
                        })) {
                            Text("Me in name color")
                        }
                    }
                } header: {
                    Text("Colors")
                }
            }
            .navigationTitle("Appearance")
        } label: {
            Text("Appearance")
        }
    }
}
