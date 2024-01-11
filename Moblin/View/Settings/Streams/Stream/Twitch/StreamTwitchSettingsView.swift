import SwiftUI

struct StreamTwitchSettingsView: View {
    @EnvironmentObject var model: Model
    var stream: SettingsStream

    func submitChannelName(value: String) {
        stream.twitchChannelName = value
        model.store()
        if stream.enabled {
            model.twitchChannelNameUpdated()
        }
    }

    func submitChannelId(value: String) {
        stream.twitchChannelId = value
        model.store()
        if stream.enabled {
            model.twitchChannelIdUpdated()
        }
    }

    var body: some View {
        Form {
            Section {
                NavigationLink(destination: TextEditView(
                    title: String(localized: "Channel name"),
                    value: stream.twitchChannelName,
                    onSubmit: submitChannelName,
                    capitalize: true
                )) {
                    TextItemView(name: String(localized: "Channel name"), value: stream.twitchChannelName)
                }
            } footer: {
                Text("The name of your channel.")
            }
            Section {
                NavigationLink(destination: TextEditView(
                    title: String(localized: "Channel id"),
                    value: stream.twitchChannelId,
                    onSubmit: submitChannelId
                )) {
                    TextItemView(name: String(localized: "Channel id"), value: stream.twitchChannelId)
                }
            } footer: {
                Text(
                    "A large number. Use developer tools (F11) in your browser. Look at websocket messages."
                )
            }
        }
        .navigationTitle("Twitch")
        .toolbar {
            SettingsToolbar()
        }
    }
}
