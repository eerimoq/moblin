import SwiftUI

struct DisplaySettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            Section {
                NavigationLink(destination: LocalOverlaysSettingsView()) {
                    Text("Local overlays")
                }
                TapScreenToFocusSettingsView()
                Toggle("Battery percentage", isOn: Binding(get: {
                    model.database.batteryPercentage!
                }, set: { value in
                    model.database.batteryPercentage = value
                    model.store()
                }))
                NavigationLink(destination: QuickButtonsSettingsView()) {
                    Text("Buttons")
                }
            }
        }
        .navigationTitle("Display")
        .toolbar {
            SettingsToolbar()
        }
    }
}
