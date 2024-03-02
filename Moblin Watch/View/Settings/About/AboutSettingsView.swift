import SwiftUI

struct AboutSettingsView: View {
    var body: some View {
        Form {
            Section {
                TextItemView(name: String(localized: "Version"), value: appVersion())
            }
        }
        .navigationTitle("About")
    }
}
