import SwiftUI

struct StreamDiscordSettingsView: View {
    @EnvironmentObject var model: Model
    var stream: SettingsStream

    func submitSnapshotWebhookUrl(value: String) {
        let url = cleanUrl(url: value)
        stream.discordSnapshotWebhook = url
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
            } footer: {
                VStack(alignment: .leading) {
                    Text("Auotmatically upload snapshots to a channel in your Discord server when live.")
                    Text("")
                    Text("Create a webhook in your Discord server's settings and paste it's URL above.")
                }
            }
        }
        .navigationTitle("Discord")
    }
}
