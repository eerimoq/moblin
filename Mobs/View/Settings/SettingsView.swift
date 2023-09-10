import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: Model
    @State private var isPresentingResetConfirm: Bool = false

    var database: Database {
        get {
            model.settings.database
        }
    }

    func version() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
    }
    
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
                HStack {
                    Spacer()
                    Button("Reset settings", role: .destructive) {
                        isPresentingResetConfirm = true
                    }
                    .confirmationDialog("Are you sure?", isPresented: $isPresentingResetConfirm) {
                        Button("Reset settings", role: .destructive) {
                            model.settings.reset()
                            model.reloadStream()
                            model.resetSelectedScene()
                         }
                    }
                    Spacer()
                }
            }
        }
        .navigationTitle("Settings")
    }
}
