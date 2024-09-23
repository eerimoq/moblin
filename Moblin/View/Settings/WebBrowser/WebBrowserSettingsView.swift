import SwiftUI

struct WebBrowserSettingsView: View {
    @EnvironmentObject var model: Model

    private func submitHome(value: String) {
        model.database.webBrowser!.home = value
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
    }
}
