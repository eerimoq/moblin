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
                    title: String(localized: "Snapshot Webhook URL"),
                    value: stream.discordSnapshotWebhook!,
                    onSubmit: submitSnapshotWebhookUrl,
                    keyboardType: .URL
                )
            } footer: {
                Text("Upload snapshots to Discord using a webhook.")
            }
        }
        .navigationTitle("Discord")
    }
}
