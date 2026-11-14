import SwiftUI

struct ChatSettingsAppearanceView: View {
    let model: Model
    @ObservedObject var database: Database
    @ObservedObject var chat: SettingsChat

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    HStack {
                        Text("Size")
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
                    if database.showAllSettings {
                        FontSettingsView(font: $chat.font) {
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
                    }
                } header: {
                    Text("Font")
                }
                if database.showAllSettings {
                    Section {
                        HStack {
                            Text("Big GIF scale")
                            Slider(
                                value: $chat.bigGifScale,
                                in: 1 ... 10,
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
                            .onChange(of: chat.bigGifScale) { _ in
                                model.reloadChatMessages()
                            }
                            Text(String(Int(chat.bigGifScale)))
                                .frame(width: 25)
                        }
                        Picker("Display style", selection: $chat.displayStyle) {
                            ForEach(SettingsChatDisplayStyle.allCases, id: \.self) { displayStyle in
                                Text(displayStyle.toString())
                            }
                        }
                        Toggle("Timestamp", isOn: $chat.timestampColorEnabled)
                            .onChange(of: chat.timestampColorEnabled) { _ in
                                model.reloadChatMessages()
                            }
                        Toggle("Badges", isOn: $chat.badges)
                            .onChange(of: chat.badges) { _ in
                                model.reloadChatMessages()
                            }
                        Toggle("Animated emotes", isOn: $chat.animatedEmotes)
                            .onChange(of: chat.animatedEmotes) { _ in
                                model.reloadChatMessages()
                            }
                        Toggle("Shared chat icons", isOn: $chat.sharedChatIcons)
                            .onChange(of: chat.sharedChatIcons) { _ in
                                model.reloadChatMessages()
                            }
                        Toggle("Compact events", isOn: $chat.compactEvents)
                            .onChange(of: chat.compactEvents) { _ in
                                model.reloadChatMessages()
                            }
                    } header: {
                        Text("General")
                    }
                }
                Section {
                    if database.showAllSettings {
                        RgbColorPickerView(title: "Timestamp", color: $chat.timestampColorColor) {
                            chat.timestampColor = $0
                            model.reloadChatMessages()
                        }
                        RgbColorPickerView(title: "Name", color: $chat.usernameColorColor) {
                            chat.usernameColor = $0
                            model.reloadChatMessages()
                        }
                        Toggle("Same color for all names", isOn: $chat.sameUsernameColor)
                        RgbColorPickerView(title: "Message", color: $chat.messageColorColor) {
                            chat.messageColor = $0
                            model.reloadChatMessages()
                        }
                    }
                    Toggle(isOn: $chat.backgroundColorEnabled) {
                        RgbColorPickerView(title: "Background", color: $chat.backgroundColorColor) {
                            chat.backgroundColor = $0
                            model.reloadChatMessages()
                        }
                    }
                    .onChange(of: chat.backgroundColorEnabled) { _ in
                        model.reloadChatMessages()
                    }
                    Toggle(isOn: $chat.shadowColorEnabled) {
                        RgbColorPickerView(title: "Border", color: $chat.shadowColorColor) {
                            chat.shadowColor = $0
                            model.reloadChatMessages()
                        }
                    }
                    .onChange(of: chat.shadowColorEnabled) { _ in
                        model.reloadChatMessages()
                    }
                    if database.showAllSettings {
                        Toggle("Me in name color", isOn: $chat.meInUsernameColor)
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
