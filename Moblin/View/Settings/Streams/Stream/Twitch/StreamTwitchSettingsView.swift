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
                if stream.twitchAccessToken!.isEmpty {
                    Button {
                        model.showTwitchAuth = true
                        model.twitchLogin(stream: stream)
                    } label: {
                        HStack {
                            Spacer()
                            Text("Login")
                            Spacer()
                        }
                    }
                } else {
                    Button {
                        model.twitchLogout(stream: stream)
                    } label: {
                        HStack {
                            Spacer()
                            Text("Logout")
                            Spacer()
                        }
                    }
                }
            }
            Section {
                TextEditNavigationView(
                    title: String(localized: "Channel name"),
                    value: stream.twitchChannelName,
                    onSubmit: submitChannelName,
                    capitalize: true
                )
            } footer: {
                Text("The name of your channel.")
            }
            Section {
                TextEditNavigationView(
                    title: String(localized: "Channel id"),
                    value: stream.twitchChannelId,
                    onSubmit: submitChannelId
                )
            } footer: {
                VStack(alignment: .leading) {
                    Text("Needed for channel chat emotes and number of viewers.")
                    Text("")
                    Text(
                        """
                        Use https://streamscharts.com/tools/convert-username to convert your \
                        channel name to your channel id.
                        """
                    )
                }
            }
        }
        .navigationTitle("Twitch")
        .toolbar {
            SettingsToolbar()
        }
    }
}
