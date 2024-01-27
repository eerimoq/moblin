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
                Toggle("Chat", isOn: Binding(get: {
                    show.chat
                }, set: { value in
                    show.chat = value
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
                Toggle("Audio level", isOn: Binding(get: {
                    show.audioLevel
                }, set: { value in
                    show.audioLevel = value
                    model.store()
                }))
                Toggle("Location", isOn: Binding(get: {
                    show.location!
                }, set: { value in
                    show.location = value
                    model.store()
                }))
                Toggle("RTMP server", isOn: Binding(get: {
                    show.rtmpSpeed!
                }, set: { value in
                    show.rtmpSpeed = value
                    model.store()
                }))
                Toggle("Remote control", isOn: Binding(get: {
                    show.remoteControl!
                }, set: { value in
                    show.remoteControl = value
                    model.store()
                }))
                Toggle("Game controllers", isOn: Binding(get: {
                    show.gameController!
                }, set: { value in
                    show.gameController = value
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
                Toggle("Browser widgets", isOn: Binding(get: {
                    show.browserWidgets!
                }, set: { value in
                    show.browserWidgets = value
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
