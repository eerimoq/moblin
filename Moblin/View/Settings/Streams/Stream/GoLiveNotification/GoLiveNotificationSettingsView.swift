import SwiftUI

struct GoLiveNotificationDiscordTextSettingsView: View {
    @ObservedObject var stream: SettingsStream
    @FocusState var editingText: Bool

    var body: some View {
        VStack {
            MultiLineTextFieldView(value: $stream.goLiveNotificationDiscordMessage)
                .keyboardType(.default)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .focused($editingText)
            HStack {
                Text("")
                Spacer()
                Button("Done") {
                    editingText = false
                }
                .disabled(!editingText)
            }
        }
    }
}

private struct GoLiveNotificationDiscordSettingsView: View {
    @ObservedObject var stream: SettingsStream

    var body: some View {
        Form {
            Section {
                GoLiveNotificationDiscordTextSettingsView(stream: stream)
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
                DiscordLogoAndNameView()
            }
        }
        .navigationTitle("Go live notification")
    }
}
