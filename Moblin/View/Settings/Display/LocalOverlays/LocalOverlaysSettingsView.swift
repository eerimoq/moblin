import SwiftUI

private let audioLevels = [String(localized: "Bar"), String(localized: "Decibel")]

struct LocalOverlaysSettingsView: View {
    @EnvironmentObject var model: Model

    var show: SettingsShow {
        model.database.show
    }

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
            Section("Top left") {
                Toggle("Stream", isOn: Binding(get: {
                    show.stream
                }, set: { value in
                    show.stream = value
                    model.store()
                }))
                Toggle("Camera", isOn: Binding(get: {
                    show.cameras!
                }, set: { value in
                    show.cameras = value
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
                Toggle("OBS status", isOn: Binding(get: {
                    show.obsStatus!
                }, set: { value in
                    show.obsStatus = value
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
                NavigationLink(destination: InlinePickerView(title: String(localized: "Audio level"),
                                                             onChange: onAudioLevelChange,
                                                             items: InlinePickerItem
                                                                 .fromStrings(values: audioLevels),
                                                             selectedId: audioLevel()))
                {
                    Toggle(isOn: Binding(get: {
                        show.audioLevel
                    }, set: { value in
                        show.audioLevel = value
                        model.store()
                    })) {
                        TextItemView(name: String(localized: "Audio level"), value: audioLevel())
                    }
                }
                Toggle("RTMP server bitrate", isOn: Binding(get: {
                    show.rtmpSpeed!
                }, set: { value in
                    show.rtmpSpeed = value
                    model.store()
                }))
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
