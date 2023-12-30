import SwiftUI

private let audioLevels = [String(localized: "Bar"), String(localized: "Decibel")]

struct DisplaySettingsView: View {
    @EnvironmentObject var model: Model

    var chat: SettingsChat {
        model.database.chat
    }

    private func onAudioLevelChange(type: String) {
        model.database.show.audioBar = type == String(localized: "Bar")
        model.store()
    }

    private func audioLevel() -> String {
        return model.database.show.audioBar ? String(localized: "Bar") : String(localized: "Decibel")
    }

    var body: some View {
        Form {
            Section {
                NavigationLink(destination: LocalOverlaysChatSettingsView(
                    timestampColor: chat.timestampColor.color(),
                    usernameColor: chat.usernameColor.color(),
                    messageColor: chat.messageColor.color(),
                    backgroundColor: chat.backgroundColor.color(),
                    shadowColor: chat.shadowColor.color(),
                    height: chat.height!,
                    width: chat.width!,
                    fontSize: chat.fontSize
                )) {
                    Text("Chat")
                }
                NavigationLink(destination: QuickButtonsSettingsView()) {
                    Text("Buttons")
                }
                Toggle("Battery percentage", isOn: Binding(get: {
                    model.database.batteryPercentage!
                }, set: { value in
                    model.database.batteryPercentage = value
                    model.store()
                }))
                NavigationLink(destination: LocalOverlaysSettingsView()) {
                    Text("Local overlays")
                }
                NavigationLink(destination: InlinePickerView(title: String(localized: "Audio level"),
                                                             onChange: onAudioLevelChange,
                                                             items: InlinePickerItem
                                                                 .fromStrings(values: audioLevels),
                                                             selectedId: audioLevel()))
                {
                    Text("Audio level")
                }
                NavigationLink(destination: LocalOverlaysNetworkInterfaceNamesSettingsView()) {
                    Text("Network interface names")
                }
            }
        }
        .navigationTitle("Display")
        .toolbar {
            SettingsToolbar()
        }
    }
}
