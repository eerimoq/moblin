import SwiftUI

struct DisconnectProtectionSettingsView: View {
    @ObservedObject var database: Database
    @ObservedObject var disconnectProtection: SettingsDisconnectProtection

    var body: some View {
        Section {
            Picker(selection: $disconnectProtection.liveSceneId) {
                Text("-- None --")
                    .tag(nil as UUID?)
                ForEach(database.scenes) { scene in
                    Text(scene.name)
                        .tag(scene.id as UUID?)
                }
            } label: {
                Text("Live scene")
            }
            Picker(selection: $disconnectProtection.fallbackSceneId) {
                Text("-- None --")
                    .tag(nil as UUID?)
                ForEach(database.scenes) { scene in
                    Text(scene.name)
                        .tag(scene.id as UUID?)
                }
            } label: {
                Text("Fallback scene")
            }
        } header: {
            Text("Disconnect protection")
        }
    }
}
