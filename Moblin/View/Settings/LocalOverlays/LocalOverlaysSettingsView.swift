import SwiftUI

private let audioLevels = ["Bar", "Decibel"]

struct LocalOverlaysSettingsView: View {
    @EnvironmentObject var model: Model

    var show: SettingsShow {
        model.database.show
    }

    var chat: SettingsChat {
        model.database.chat
    }

    private func onAudioLevelChange(type: String) {
        model.database.show.audioBar = type == "Bar"
        model.store()
    }

    private func audioLevel() -> String {
        return model.database.show.audioBar ? "Bar" : "Decibel"
    }

    var body: some View {
        Form {
            Section("Top left") {
                Toggle("Stream", isOn: Binding(get: {
                    show.stream
                }, set: { value in
                    show.stream = value
                    model.store()
                }))
                Toggle("Mic", isOn: Binding(get: {
                    show.microphone
                }, set: { value in
                    show.microphone = value
                    model.store()
                }))
                Toggle("Zoom", isOn: Binding(get: {
                    show.zoom
                }, set: { value in
                    show.zoom = value
                    model.store()
                }))
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
                    Toggle("Chat", isOn: Binding(get: {
                        show.chat
                    }, set: { value in
                        show.chat = value
                        model.store()
                    }))
                }
                Toggle("Viewers", isOn: Binding(get: {
                    show.viewers
                }, set: { value in
                    show.viewers = value
                    model.store()
                }))
            }
            Section("Top right") {
                NavigationLink(destination: InlinePickerView(title: "Audio level",
                                                             onChange: onAudioLevelChange,
                                                             items: audioLevels,
                                                             selected: audioLevel()))
                {
                    Toggle(isOn: Binding(get: {
                        show.audioLevel
                    }, set: { value in
                        show.audioLevel = value
                        model.store()
                    })) {
                        TextItemView(name: "Audio level", value: audioLevel())
                    }
                }
                Toggle("Bitrate", isOn: Binding(get: {
                    show.speed
                }, set: { value in
                    show.speed = value
                    model.store()
                }))
                Toggle("Uptime", isOn: Binding(get: {
                    show.uptime
                }, set: { value in
                    show.uptime = value
                    model.store()
                }))
            }
            Section {
                Toggle("Zoom presets", isOn: Binding(get: {
                    show.zoomPresets
                }, set: { value in
                    show.zoomPresets = value
                    model.store()
                }))
            } header: {
                Text("Bottom right")
            } footer: {
                Text("")
                Text("Local overlays do not appear on stream.")
            }
        }
        .navigationTitle("Local overlays")
        .toolbar {
            SettingsToolbar()
        }
    }
}
