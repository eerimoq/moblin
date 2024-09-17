import SwiftUI

struct DeepLinkCreatorWebBrowserSettingsView: View {
    @EnvironmentObject var model: Model
    var webBrowser: DeepLinkCreatorWebBrowser

    private func submitHome(value: String) {
        webBrowser.home = value
    }

    var body: some View {
        Form {
            Section {
                TextEditNavigationView(
                    title: String(localized: "Home"),
                    value: webBrowser.home,
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
