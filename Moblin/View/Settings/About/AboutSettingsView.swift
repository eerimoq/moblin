import SwiftUI

struct AboutSettingsView: View {
    var body: some View {
        Form {
            Section {
                TextItemView(name: String(localized: "Version"), value: appVersion())
                NavigationLink(destination: AboutVersionHistorySettingsView()) {
                    Text("Version history")
                }
                NavigationLink(destination: AboutLicensesSettingsView()) {
                    Text("Licenses")
                }
                NavigationLink(destination: AboutAttributionsSettingsView()) {
                    Text("Attributions")
                }
            }
            Section {
                Button(action: {
                    openUrl(url: "https://eerimoq.github.io/moblin/privacy-policy/en.html")
                }, label: {
                    Text("Privacy policy")
                })
                Button(action: {
                    openUrl(url: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
                }, label: {
                    Text("End-user license agreement (EULA)")
                })
            }
        }
        .navigationTitle("About")
        .toolbar {
            SettingsToolbar()
        }
    }
}
