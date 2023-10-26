import SwiftUI

struct LocalOverlaysSettingsView: View {
    @EnvironmentObject var model: Model

    var show: SettingsShow {
        model.database.show
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
                Toggle("Viewers", isOn: Binding(get: {
                    show.viewers
                }, set: { value in
                    show.viewers = value
                    model.store()
                }))
            }
            Section("Top right") {
                NavigationLink(destination: LocalOverlaysAudioLevelSettingsView(
                    meterType: model.database.show.audioBar! ?
                        "Bar" :
                        "Decibel"
                )) {
                    Toggle("Audio level", isOn: Binding(get: {
                        show.audioLevel
                    }, set: { value in
                        show.audioLevel = value
                        model.store()
                    }))
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
            Section("Bottom left") {
                NavigationLink(destination: LocalOverlaysChatSettingsView(
                    usernameColor: model.database.chat!.usernameColor.color(),
                    messageColor: model.database.chat!.messageColor.color(),
                    backgroundColor: model.database.chat!.backgroundColor.color(),
                    shadowColor: model.database.chat!.shadowColor.color()
                )) {
                    Toggle("Chat", isOn: Binding(get: {
                        show.chat
                    }, set: { value in
                        show.chat = value
                        model.store()
                    }))
                }
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
    }
}
