import SwiftUI

struct AboutSettingsView: View {
    var toolbar: Toolbar

    var body: some View {
        Form {
            Section {
                TextItemView(name: "Version", value: version())
                NavigationLink(destination: AboutLicensesSettingsView(toolbar: toolbar)) {
                    Text("Licenses")
                }
            }
        }
        .navigationTitle("About")
        .toolbar {
            toolbar
        }
    }
}
