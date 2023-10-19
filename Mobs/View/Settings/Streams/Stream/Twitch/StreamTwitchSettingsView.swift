import SwiftUI

struct StreamTwitchSettingsView: View {
    @ObservedObject var model: Model
    var toolbar: Toolbar
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
                    toolbar: toolbar,
                    title: "Channel name",
                    value: stream.twitchChannelName,
                    onSubmit: submitChannelName
                )) {
                    TextItemView(name: "Channel name", value: stream.twitchChannelName)
                }
            } footer: {
                Text("The name of your channel.")
            }
            Section {
                NavigationLink(destination: TextEditView(
                    toolbar: toolbar,
                    title: "Channel id",
                    value: stream.twitchChannelId,
                    onSubmit: submitChannelId
                )) {
                    TextItemView(name: "Channel id", value: stream.twitchChannelId)
                }
            } footer: {
                Text(
                    "A large number. Use developer tools (F11) in your browser. Look at websocket messages."
                )
            }
        }
        .navigationTitle("Twitch")
        .toolbar {
            toolbar
        }
    }
}
