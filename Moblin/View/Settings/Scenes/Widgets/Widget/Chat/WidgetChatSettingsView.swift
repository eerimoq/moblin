import SwiftUI

struct WidgetChatSettingsView: View {
    @EnvironmentObject var model: Model
    let widget: SettingsWidget
    @ObservedObject var chat: SettingsWidgetChat

    private func setEffectSettings() {
        model.getChatEffect(id: widget.id)?.setSettings(settings: chat)
    }

    var body: some View {
        Section {
            HStack {
                Text("Font size")
                Slider(
                    value: $chat.fontSize,
                    in: 10 ... 50,
                    step: 1,
                    label: {
                        EmptyView()
                    },
                    onEditingChanged: { begin in
                        guard !begin else {
                            return
                        }
                        setEffectSettings()
                    }
                )
                .onChange(of: chat.fontSize) { _ in
                    setEffectSettings()
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
                .onChange(of: chat.displayStyle) { _ in
                    setEffectSettings()
                }
                Toggle("Bold name", isOn: $chat.boldUsername)
                    .onChange(of: chat.boldUsername) { _ in
                        setEffectSettings()
                    }
                Toggle("Bold message", isOn: $chat.boldMessage)
                    .onChange(of: chat.boldMessage) { _ in
                        setEffectSettings()
                    }
                Toggle("Badges", isOn: $chat.badges)
                    .onChange(of: chat.badges) { _ in
                        setEffectSettings()
                    }
                Toggle("Streaming platform", isOn: $chat.platform)
                    .onChange(of: chat.platform) { _ in
                        setEffectSettings()
                    }
            }
        }
        Section {
            if model.database.showAllSettings {
                ColorPicker("Name", selection: $chat.usernameColorColor, supportsOpacity: false)
                    .onChange(of: chat.usernameColorColor) { _ in
                        guard let color = chat.usernameColorColor.toRgb() else {
                            return
                        }
                        chat.usernameColor = color
                        setEffectSettings()
                    }
                ColorPicker("Message", selection: $chat.messageColorColor, supportsOpacity: false)
                    .onChange(of: chat.messageColorColor) { _ in
                        guard let color = chat.messageColorColor.toRgb() else {
                            return
                        }
                        chat.messageColor = color
                        setEffectSettings()
                    }
            }
            Toggle(isOn: $chat.backgroundColorEnabled) {
                ColorPicker("Background", selection: $chat.backgroundColorColor, supportsOpacity: false)
                    .onChange(of: chat.backgroundColorColor) { _ in
                        guard let color = chat.backgroundColorColor.toRgb() else {
                            return
                        }
                        chat.backgroundColor = color
                        setEffectSettings()
                    }
            }
            .onChange(of: chat.backgroundColorEnabled) { _ in
                setEffectSettings()
            }
            Toggle(isOn: $chat.shadowColorEnabled) {
                ColorPicker("Border", selection: $chat.shadowColorColor, supportsOpacity: false)
                    .onChange(of: chat.shadowColorColor) { _ in
                        guard let color = chat.shadowColorColor.toRgb() else {
                            return
                        }
                        chat.shadowColor = color
                        setEffectSettings()
                    }
            }
            .onChange(of: chat.shadowColorEnabled) { _ in
                setEffectSettings()
            }
        } header: {
            Text("Colors")
        }
    }
}
