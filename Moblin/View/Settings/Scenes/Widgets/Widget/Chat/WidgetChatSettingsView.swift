import SwiftUI

struct WidgetChatSettingsView: View {
    let model: Model
    @ObservedObject var database: Database
    let widget: SettingsWidget
    @ObservedObject var chat: SettingsWidgetChat

    private func setEffectSettings() {
        model.getChatEffect(id: widget.id)?.setSettings(settings: chat)
    }

    var body: some View {
        Section {
            HStack {
                Text("Size")
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
            if database.showAllSettings {
                FontSettingsView(font: $chat.font) {
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
            }
        } header: {
            Text("Font")
        }
        Section {
            Picker("Messages", selection: $chat.maximumNumberOfMessages) {
                ForEach([1, 2, 3, 4, 5], id: \.self) {
                    Text(String($0))
                }
            }
            .onChange(of: chat.maximumNumberOfMessages) { _ in
                setEffectSettings()
            }
            HStack {
                Text("Height")
                Slider(value: $chat.height, in: 0.1 ... 1, step: 0.01)
                    .onChange(of: chat.height) { _ in
                        setEffectSettings()
                    }
                Text(String("\(Int(100 * chat.height))%"))
                    .frame(width: sliderValuePercentageWidth)
            }
            if database.showAllSettings {
                Picker("Display style", selection: $chat.displayStyle) {
                    ForEach(SettingsChatDisplayStyle.allCases, id: \.self) { displayStyle in
                        Text(displayStyle.toString())
                    }
                }
                .onChange(of: chat.displayStyle) { _ in
                    setEffectSettings()
                }
                Toggle("Badges", isOn: $chat.badges)
                    .onChange(of: chat.badges) { _ in
                        setEffectSettings()
                    }
                Toggle("Shared chat icons", isOn: $chat.sharedChatIcons)
                    .onChange(of: chat.sharedChatIcons) { _ in
                        setEffectSettings()
                    }
            }
        } header: {
            Text("General")
        }
        Section {
            if database.showAllSettings {
                RgbColorPickerView(title: "Name", color: $chat.usernameColorColor) {
                    chat.usernameColor = $0
                    setEffectSettings()
                }
                RgbColorPickerView(title: "Message", color: $chat.messageColorColor) {
                    chat.messageColor = $0
                    setEffectSettings()
                }
            }
            Toggle(isOn: $chat.backgroundColorEnabled) {
                RgbColorPickerView(title: "Background", color: $chat.backgroundColorColor) {
                    chat.backgroundColor = $0
                    setEffectSettings()
                }
            }
            .onChange(of: chat.backgroundColorEnabled) { _ in
                setEffectSettings()
            }
            Toggle(isOn: $chat.shadowColorEnabled) {
                RgbColorPickerView(title: "Border", color: $chat.shadowColorColor) {
                    chat.shadowColor = $0
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
