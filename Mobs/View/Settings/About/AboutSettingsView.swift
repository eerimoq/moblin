import SwiftUI

struct AboutSettingsView: View {
    var body: some View {
        Form {
            Section {
                TextItemView(name: "Version", value: version())
                /* NavigationLink(destination: AboutLicensesSettingsView()) {
                     Text("Licenses")
                 } */
            }
        }
        .navigationTitle("About")
    }
}
