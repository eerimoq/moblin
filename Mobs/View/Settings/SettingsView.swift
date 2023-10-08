import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: Model

    var body: some View {
        Form {
            Section {
                NavigationLink(destination: StreamsSettingsView(model: model)) {
                    Text("Streams")
                }
                NavigationLink(destination: ScenesSettingsView(model: model)) {
                    Text("Scenes")
                }
                NavigationLink(destination: LocalOverlaysSettingsView(model: model)) {
                    Text("Local overlays")
                }
                NavigationLink(destination: ZoomSettingsView(model: model)) {
                    Text("Zoom presets")
                }
            }
            Section {
                NavigationLink(destination: HelpAndSupportSettingsView()) {
                    Text("Help & support")
                }
                NavigationLink(destination: AboutSettingsView()) {
                    Text("About")
                }
                NavigationLink(destination: DebugSettingsView(model: model)) {
                    Text("Debug")
                }
            }
            Section {
                NavigationLink(destination: ImportExportSettingsView(model: model)) {
                    Text("Import and export settings")
                }
            }
            Section {
                ResetSettingsView(model: model)
            }
        }
        .navigationTitle("Settings")
    }
}
