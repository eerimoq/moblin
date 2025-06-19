import SwiftUI

private struct GoLiveNotificationDiscordSettingsView: View {
    @ObservedObject var stream: SettingsStream

    var body: some View {
        Form {
            Section {
                MultiLineTextFieldView(value: $stream.goLiveNotificationDiscordMessage)
                    .keyboardType(.default)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            } header: {
                Text("Message")
            } footer: {
                VStack(alignment: .leading) {
                    Text("""
                    Markdown works. Add emojis as <:myEmojiName:8912739817498174>. \
                    Send \\\\:myEmojiName: in Discord to get it.
                    """)
                    Text("")
                    Text("A snapshot will also be uploaded.")
                }
            }
            Section {
                TextEditNavigationView(
                    title: String(localized: "Webhook URL"),
                    value: stream.goLiveNotificationDiscordWebhookUrl,
                    onSubmit: {
                        stream.goLiveNotificationDiscordWebhookUrl = cleanUrl(url: $0)
                    },
                    placeholder: "https://discord.com/api/webhooks/foobar"
                )
            }
            Section {
                Toggle("Send to #i-am-live", isOn: $stream.goLiveNotificationDiscordIAmLive)
            } footer: {
                Text("""
                When enabled, the notification will be sent to the #i-am-live \
                channel in Moblin's Discord server as well.
                """)
            }
        }
        .navigationTitle("Discord")
    }
}

struct GoLiveNotificationSettingsView: View {
    @ObservedObject var stream: SettingsStream

    var body: some View {
        Form {
            NavigationLink {
                GoLiveNotificationDiscordSettingsView(stream: stream)
            } label: {
                Text("Discord")
            }
        }
        .navigationTitle("Go live notification")
    }
}
