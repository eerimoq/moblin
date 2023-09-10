import SwiftUI

struct AboutSettingsView: View {
    func version() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
    }
    
    var body: some View {
        Form {
            Section {
                TextItemView(name: "Version", value: version())
                NavigationLink(destination: AboutLicensesSettingsView()) {
                    Text("Licenses")
                }
            }
        }
        .navigationTitle("About")
    }
}
