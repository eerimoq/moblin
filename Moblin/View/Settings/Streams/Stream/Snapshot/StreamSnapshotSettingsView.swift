import SwiftUI

private func drawSnapshotCard(context: GraphicsContext, time: Double) {
    var path = Path()
    path.move(to: CGPoint(x: 164, y: 83))
    path.addLine(to: CGPoint(x: 186, y: 83))
    strokeTradingCardDash(context: context,
                          path: path,
                          color: Color(red: 0x58 / 255, green: 0x65 / 255, blue: 0xF2 / 255),
                          lineWidth: 3,
                          dash: 6,
                          gap: 6,
                          time: time)
}

struct StreamSnapshotSettingsView: View {
    let model: Model
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
                TradingCardView(name: "Snapshot",
                                background: Color(red: 0xDB / 255, green: 0xD7 / 255, blue: 0xE7 / 255),
                                draw: drawSnapshotCard)
            }
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
