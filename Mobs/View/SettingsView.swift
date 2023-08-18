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
            Toggle("Chat", isOn: $model.isChatOn)
            Toggle("Viewers", isOn: $model.isViewersOn)
            Toggle("Uptime", isOn: $model.isUptimeOn)
        }
        .navigationTitle("Settings")
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(model: Model())
    }
}
