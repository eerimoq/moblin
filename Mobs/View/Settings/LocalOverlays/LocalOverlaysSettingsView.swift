import SwiftUI

struct LocalOverlaysSettingsView: View {
    @ObservedObject var model: Model

    var show: SettingsShow {
        model.database.show
    }

    var body: some View {
        Form {
            Section {
                Toggle("Stream", isOn: Binding(get: {
                    show.stream
                }, set: { value in
                    show.stream = value
                    model.store()
                }))
                Toggle("Viewers", isOn: Binding(get: {
                    show.viewers
                }, set: { value in
                    show.viewers = value
                    model.store()
                }))
                Toggle("Chat", isOn: Binding(get: {
                    show.chat
                }, set: { value in
                    show.chat = value
                    model.store()
                }))
                Toggle("Speed", isOn: Binding(get: {
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
                Toggle("Audio level", isOn: Binding(get: {
                    show.audioLevel!
                }, set: { value in
                    show.audioLevel = value
                    model.store()
                }))
            } footer: {
                Text("Local overlays do not appear on stream.")
            }
        }
        .navigationTitle("Local overlays")
    }
}
