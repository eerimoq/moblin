import SwiftUI

struct HelpAndSupportSettingsView: View {
    func openUrl(url: String) {
        UIApplication.shared.open(URL(string: url)!)
    }

    var body: some View {
        Form {
            Section {
                Button(action: {
                    openUrl(url: "https://discord.gg/nt3UwHqbMM")
                }, label: {
                    Text("Discord")
                })
                Button(action: {
                    openUrl(url: "https://github.com/eerimoq/moblin")
                }, label: {
                    Text("Github")
                })
            } footer: {
                Text("""
                Feel free to join Moblin Discord server or write an issue on \
                Github if you need help or want to give feedback.
                """)
            }
        }
        .navigationTitle("Help & support")
        .toolbar {
            SettingsToolbar()
        }
    }
}
