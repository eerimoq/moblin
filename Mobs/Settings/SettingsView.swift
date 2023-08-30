import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: Model

    var database: Database {
        get {
            model.settings.database
        }
    }

    var body: some View {
        Form {
            NavigationLink(destination: ConnectionsSettingsView(model: model)) {
                Text("Connections")
            }
            NavigationLink(destination: ScenesSettingsView(model: model)) {
                Text("Scenes")
            }
            Toggle("Connection", isOn: Binding(get: {
                database.show.connection
            }, set: { value in
                database.show.connection = value
                model.settings.store()
            }))
            Toggle("Viewers", isOn: Binding(get: {
                database.show.viewers
            }, set: { value in
                database.show.viewers = value
                model.settings.store()
            }))
            Toggle("Uptime", isOn: Binding(get: {
                database.show.uptime
            }, set: { value in
                database.show.uptime = value
                model.settings.store()
            }))
            Toggle("Chat", isOn: Binding(get: {
                database.show.chat
            }, set: { value in
                database.show.chat = value
                model.settings.store()
            }))
        }
        .navigationTitle("Settings")
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(model: Model())
    }
}
