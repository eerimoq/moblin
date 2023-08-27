import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: Model
    
    var database: Database {
        get {
            database
        }
    }
    
    var body: some View {
        Form {
            NavigationLink(destination: ConnectionsSettingsView(model: self.model)) {
                Text("Connections")
            }
            NavigationLink(destination: ScenesSettingsView(model: self.model)) {
                Text("Scenes")
            }
            Toggle("Chat", isOn: Binding(get: {
                database.chat
            }, set: { value in
                database.chat = value
                model.settings.store()
            }))
            Toggle("Viewers", isOn: Binding(get: {
                database.viewers
            }, set: { value in
                database.viewers = value
                model.settings.store()
            }))
            Toggle("Uptime", isOn: Binding(get: {
                database.uptime
            }, set: { value in
                database.uptime = value
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
