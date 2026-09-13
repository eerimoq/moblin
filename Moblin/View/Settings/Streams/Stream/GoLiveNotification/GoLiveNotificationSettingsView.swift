import SwiftUI

struct GoLiveNotificationDiscordTextSettingsView: View {
    @ObservedObject var stream: SettingsStream
    @FocusState private var editingText: Bool

    var body: some View {
        Section {
            MultiLineTextFieldView(value: $stream.goLiveNotificationDiscordMessage, placeholder: "My text")
                .keyboardType(.default)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .focused($editingText)
        } header: {
            Text("Message")
        } footer: {
            VStack(alignment: .leading) {
                MultiLineTextFieldDoneButtonView(editingText: $editingText)
                Text("""
                Markdown works. Add emojis as <:myEmojiName:8912739817498174>. \
                Send \\\\:myEmojiName: in Discord to get it.
                """)
                Text("")
                Text("A snapshot will also be uploaded.")
            }
        }
    }
}

private struct GoLiveNotificationDiscordSettingsView: View {
    @ObservedObject var stream: SettingsStream

    var body: some View {
        Form {
            GoLiveNotificationDiscordTextSettingsView(stream: stream)
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
            if !isMac() {
                Section {
                    Toggle("Moblin website", isOn: $stream.goLiveNotificationMoblinWebsite)
                } footer: {
                    Text("""
                    List the Twitch, YouTube and Kick channels you are logged in to under "Who's streaming \
                    with Moblin" on [Moblin website](https://moblin.app) when you go live.
                    """)
                }
            }
        }
        .navigationTitle("Go live notification")
    }
}
