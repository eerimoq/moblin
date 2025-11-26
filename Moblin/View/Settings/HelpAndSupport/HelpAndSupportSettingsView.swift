import SwiftUI

struct HelpAndSupportSettingsView: View {
    var body: some View {
        Form {
            Section {
                Button {
                    openUrl(url: "https://discord.gg/kh3KMng4JV")
                } label: {
                    DiscordLogoAndNameView()
                }
                Button {
                    openUrl(url: "https://github.com/eerimoq/moblin")
                } label: {
                    Text("Github")
                }
            } footer: {
                Text("""
                Feel free to join Moblin Discord server or write an issue on \
                Github if you need help or want to give feedback.
                """)
            }
        }
        .navigationTitle("Help and support")
    }
}
