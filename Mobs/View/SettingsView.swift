import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: Model
    
    var body: some View {
        Form {
            NavigationLink(destination: ConnectionsSettingsView(model: self.model)) {
                Text("Connections")
            }
            NavigationLink(destination: ScenesSettingsView(model: self.model)) {
                Text("Scenes")
            }
            Toggle("Chat", isOn: Binding(get: {
                model.settings.database.chat
            }, set: { value in
                model.settings.database.chat = value
                model.settings.store()
            }))
            Toggle("Viewers", isOn: Binding(get: {
                model.settings.database.viewers
            }, set: { value in
                model.settings.database.viewers = value
                model.settings.store()
            }))
            Toggle("Uptime", isOn: Binding(get: {
                model.settings.database.uptime
            }, set: { value in
                model.settings.database.uptime = value
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
