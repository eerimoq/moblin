import SwiftUI

struct AboutSettingsView: View {
    @State var presentingVersionHistory: Bool = false

    var body: some View {
        Form {
            Section {
                TextItemView(name: String(localized: "Version"), value: appVersion())
                NavigationLink {
                    AboutLicensesSettingsView()
                } label: {
                    Text("Licenses")
                }
                NavigationLink {
                    AboutAttributionsSettingsView()
                } label: {
                    Text("Attributions")
                }
            }
            Section {
                TextButtonView("Version history") {
                    presentingVersionHistory = true
                }
                .sheet(isPresented: $presentingVersionHistory) {
                    ZStack {
                        AboutVersionHistorySettingsView()
                        CloseButtonTopRightView {
                            presentingVersionHistory = false
                        }
                    }
                }
            }
            Section {
                Button {
                    openUrl(url: "https://eerimoq.github.io/moblin/privacy-policy/en.html")
                } label: {
                    Text("Privacy policy")
                }
                Button {
                    openUrl(url: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
                } label: {
                    Text("End-user license agreement (EULA)")
                }
            }
        }
        .navigationTitle("About")
    }
}
