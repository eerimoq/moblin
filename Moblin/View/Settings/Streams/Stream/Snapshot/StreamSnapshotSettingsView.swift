import SwiftUI

struct StreamSnapshotSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var stream: SettingsStream
    @ObservedObject var recording: SettingsStreamRecording

    func submitSnapshotWebhookUrl(value: String) {
        let url = cleanUrl(url: value)
        stream.discordSnapshotWebhook = url
    }

    func submitSnapshotChatBotWebhookUrl(value: String) {
        let url = cleanUrl(url: value)
        stream.discordChatBotSnapshotWebhook = url
    }

    var body: some View {
        Form {
            Section {
                Toggle("Clean snapshots", isOn: $recording.cleanSnapshots)
                    .onChange(of: recording.cleanSnapshots) { _ in
                        model.setCleanSnapshots()
                    }
            } footer: {
                Text("Do not show widgets in snapshots.")
            }
            Section {
                TextEditNavigationView(
                    title: String(localized: "Webhook URL"),
                    value: stream.discordSnapshotWebhook,
                    onSubmit: submitSnapshotWebhookUrl,
                    placeholder: "https://discord.com/api/webhooks/foobar"
                )
                TextEditNavigationView(
                    title: String(localized: "Chat bot webhook URL"),
                    value: stream.discordChatBotSnapshotWebhook,
                    onSubmit: submitSnapshotChatBotWebhookUrl,
                    placeholder: "https://discord.com/api/webhooks/foobar"
                )
                Toggle("Only when live", isOn: $stream.discordSnapshotWebhookOnlyWhenLive)
            } header: {
                DiscordLogoAndNameView()
            } footer: {
                VStack(alignment: .leading) {
                    Text("""
                    Automatically upload quick button snapshots and chat bot snapshots to channels \
                    in your Discord server.
                    """)
                    Text("")
                    Text("Create a webhook in your Discord server's settings and paste it's URL above.")
                }
            }
        }
        .navigationTitle("Snapshot")
    }
}
