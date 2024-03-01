import SwiftUI

struct StreamTwitchSettingsView: View {
    var model: Model
    var stream: SettingsStream
    var twitchAuth: TwitchAuth

    init(model: Model, stream: SettingsStream) {
        self.model = model
        self.stream = stream
        twitchAuth = TwitchAuth(model: model)
    }

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
        VStack {
            Button(
                action: {
                    self.twitchAuth.startAuthentication(stream: stream)
                },
                label: {
                    Text(stream.twitchAccessToken != nil ? "Connected" : "Connect with Twitch")
                        .padding()
                        .foregroundColor(.white)
                        .background(Color.purple)
                        .cornerRadius(8)
                }
            )
            .padding()

            Form {
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
}
