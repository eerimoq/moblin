import SwiftUI

struct AboutSettingsView: View {
    var body: some View {
        Form {
            Section {
                TextItemView(name: "Version", value: version())
                NavigationLink(destination: AboutDesignedBySettingsView()) {
                    Text("Designed by")
                }
                NavigationLink(destination: AboutLicensesSettingsView()) {
                    Text("Licenses")
                }
            }
        }
        .navigationTitle("About")
        .toolbar {
            SettingsToolbar()
        }
    }
}
