import SwiftUI

struct StreamDiscordSettingsView: View {
    // periphery:ignore
    @EnvironmentObject var model: Model
    var stream: SettingsStream

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
                TextEditNavigationView(
                    title: String(localized: "Snapshot webhook URL"),
                    value: stream.discordSnapshotWebhook!,
                    onSubmit: submitSnapshotWebhookUrl,
                    keyboardType: .URL
                )
                TextEditNavigationView(
                    title: String(localized: "Chat bot snapshot webhook URL"),
                    value: stream.discordChatBotSnapshotWebhook!,
                    onSubmit: submitSnapshotChatBotWebhookUrl,
                    keyboardType: .URL
                )
                Toggle(isOn: Binding(get: {
                    stream.discordSnapshotWebhookOnlyWhenLive!
                }, set: { value in
                    stream.discordSnapshotWebhookOnlyWhenLive = value
                })) {
                    Text("Only when live")
                }
            } footer: {
                VStack(alignment: .leading) {
                    Text("""
                    Auotmatically upload quick button snapshots and chat bot snapshots to channels \
                    in your Discord server.
                    """)
                    Text("")
                    Text("Create a webhook in your Discord server's settings and paste it's URL above.")
                }
            }
        }
        .navigationTitle("Discord")
    }
}
