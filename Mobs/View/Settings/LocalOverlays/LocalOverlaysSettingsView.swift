import SwiftUI

struct LocalOverlaysSettingsView: View {
    @ObservedObject var model: Model
    @State private var isPresentingResetConfirm: Bool = false

    var database: Database {
        get {
            model.settings.database
        }
    }

    var body: some View {
        Form {
            Section {
                Toggle("Stream", isOn: Binding(get: {
                    database.show.stream
                }, set: { value in
                    database.show.stream  = value
                    model.store()
                }))
                Toggle("Viewers", isOn: Binding(get: {
                    database.show.viewers
                }, set: { value in
                    database.show.viewers = value
                    model.store()
                }))
                Toggle("Uptime", isOn: Binding(get: {
                    database.show.uptime
                }, set: { value in
                    database.show.uptime = value
                    model.store()
                }))
                Toggle("Chat", isOn: Binding(get: {
                    database.show.chat
                }, set: { value in
                    database.show.chat = value
                    model.store()
                }))
                Toggle("Speed", isOn: Binding(get: {
                    database.show.speed
                }, set: { value in
                    database.show.speed = value
                    model.store()
                }))
                Toggle("FPS", isOn: Binding(get: {
                    database.show.fps
                }, set: { value in
                    database.show.fps = value
                    model.store()
                }))
            } footer: {
                Text("Local overlays do not appear on stream.")
            }
        }
        .navigationTitle("Local overlays")
    }
}
