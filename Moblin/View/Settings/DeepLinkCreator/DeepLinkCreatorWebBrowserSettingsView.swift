import SwiftUI

struct DeepLinkCreatorWebBrowserSettingsView: View {
    @ObservedObject var webBrowser: DeepLinkCreatorWebBrowser

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
                    capitalize: false
                )
            }
        }
        .navigationTitle("Web browser")
    }
}
