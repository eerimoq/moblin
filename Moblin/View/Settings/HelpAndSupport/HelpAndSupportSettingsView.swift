import SwiftUI

struct HelpAndSupportSettingsView: View {
    var body: some View {
        Form {
            Section {
                ExternalUrlButtonView(url: "https://discord.moblin.app") {
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
            Section {
                FeatureVideosGridView(videos: FeatureVideo.all)
            } header: {
                Text("Videos")
            }
        }
        .navigationTitle("Help and support")
    }
}
