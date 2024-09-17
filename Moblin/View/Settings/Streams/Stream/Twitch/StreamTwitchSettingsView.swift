import SwiftUI

struct StreamTwitchSettingsView: View {
    @EnvironmentObject var model: Model
    var stream: SettingsStream
    @State var loggedIn: Bool

    func submitChannelName(value: String) {
        stream.twitchChannelName = value
        if stream.enabled {
            model.twitchChannelNameUpdated()
        }
    }

    func submitChannelId(value: String) {
        stream.twitchChannelId = value
        if stream.enabled {
            model.twitchChannelIdUpdated()
        }
    }

    func onLoggedIn() {
        loggedIn = true
    }

    var body: some View {
        Form {
            Section {
                if !loggedIn {
                    Button {
                        model.showTwitchAuth = true
                        model.twitchLogin(stream: stream, onComplete: onLoggedIn)
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
                        loggedIn = false
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
