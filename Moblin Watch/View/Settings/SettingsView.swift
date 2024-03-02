import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            Section {
                NavigationLink(destination: AboutSettingsView()) {
                    Text("About")
                }
            }
        }
        .navigationTitle("Settings")
    }
}
