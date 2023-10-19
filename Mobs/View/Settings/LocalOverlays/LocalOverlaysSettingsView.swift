import SwiftUI

struct LocalOverlaysSettingsView: View {
    @ObservedObject var model: Model
    var toolbar: Toolbar

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
                    show.microphone!
                }, set: { value in
                    show.microphone = value
                    model.store()
                }))
                Toggle("Zoom", isOn: Binding(get: {
                    show.zoom!
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
                Toggle("Audio level", isOn: Binding(get: {
                    show.audioLevel!
                }, set: { value in
                    show.audioLevel = value
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
            Section("Bottom left") {
                Toggle("Chat", isOn: Binding(get: {
                    show.chat
                }, set: { value in
                    show.chat = value
                    model.store()
                }))
            }
            Section {
                Toggle("Zoom presets", isOn: Binding(get: {
                    show.zoomPresets!
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
            toolbar
        }
    }
}
