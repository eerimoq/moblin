import SwiftUI

struct WebBrowserSettingsView: View {
    @EnvironmentObject var model: Model

    private func submitHome(value: String) {
        guard isValidUrl(url: value, allowedSchemes: ["http", "https"]) != nil else {
            return
        }
        model.database.webBrowser!.home = value
        model.store()
    }

    var body: some View {
        Form {
            Section {
                TextEditNavigationView(
                    title: String(localized: "Home"),
                    value: model.database.webBrowser!.home,
                    onSubmit: submitHome,
                    capitalize: false,
                    keyboardType: .URL
                )
            }
        }
        .navigationTitle("Web browser")
        .toolbar {
            SettingsToolbar()
        }
    }
}
