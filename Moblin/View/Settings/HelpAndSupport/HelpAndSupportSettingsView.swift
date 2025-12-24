import SwiftUI

struct HelpAndSupportSettingsView: View {
    var body: some View {
        Form {
            Section {
                ExternalUrlButtonView(url: "https://discord.gg/kh3KMng4JV") {
                    DiscordLogoAndNameView()
                }
                ExternalUrlButtonView(url: "https://github.com/eerimoq/moblin") {
                    GithubLogoAndNameView()
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
