import SwiftUI

struct TwitchAlertsSettingsView: View {
    let title: String
    @ObservedObject var alerts: SettingsTwitchAlerts

    var body: some View {
        Form {
            Section {
                Toggle("Follows", isOn: $alerts.follows)
                Toggle("Subscriptions", isOn: $alerts.subscriptions)
                Toggle("Gift subscriptions", isOn: $alerts.giftSubscriptions)
                Toggle("Resubscriptions", isOn: $alerts.resubscriptions)
                Toggle("Rewards", isOn: $alerts.rewards)
                Toggle("Raids", isOn: $alerts.raids)
                Toggle("Bits", isOn: $alerts.cheers)
                TextEditNavigationView(
                    title: String(localized: "Minimum bits"),
                    value: String(alerts.minimumCheerBits),
                    onSubmit: {
                        alerts.minimumCheerBits = Int($0) ?? 0
                    }
                )
            }
        }
        .navigationTitle(title)
    }
}

struct StreamTwitchSettingsView: View {
    @EnvironmentObject var model: Model
    var stream: SettingsStream
    @State var loggedIn: Bool
    @State var streamTitle: String?

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
        getStreamTitle()
    }

    private func getStreamTitle() {
        model.getTwitchChannelInformation(stream: stream) { channelInformation in
            streamTitle = channelInformation.title
        }
    }

    var body: some View {
        Form {
            Section {
                if !loggedIn {
                    Button {
                        model.showTwitchAuth = true
                        model.twitchLogin(stream: stream, onComplete: onLoggedIn)
                    } label: {
                        HCenter {
                            Text("Login")
                        }
                    }
                } else {
                    Button {
                        model.twitchLogout(stream: stream)
                        loggedIn = false
                    } label: {
                        HCenter {
                            Text("Logout")
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
            if false {
                Section {
                    Toggle("Multi track", isOn: Binding(get: {
                        stream.twitchMultiTrackEnabled
                    }, set: { value in
                        stream.twitchMultiTrackEnabled = value
                    }))
                }
            }
            if loggedIn {
                Section {
                    NavigationLink {
                        TextEditView(
                            title: String(localized: "Stream title"),
                            value: streamTitle ?? "",
                            onSubmit: { value in
                                streamTitle = value
                                model.setTwitchStreamTitle(stream: stream, title: value)
                            }
                        )
                    } label: {
                        HStack {
                            Text("Stream title")
                            Spacer()
                            if let streamTitle {
                                Text(streamTitle)
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                            } else {
                                ProgressView()
                            }
                        }
                    }
                }
            }
            Section {
                NavigationLink {
                    TwitchAlertsSettingsView(title: String(localized: "Chat"), alerts: stream.twitchChatAlerts)
                } label: {
                    Text("Chat")
                }
                NavigationLink {
                    TwitchAlertsSettingsView(title: String(localized: "Toasts"), alerts: stream.twitchToastAlerts)
                } label: {
                    Text("Toasts")
                }
            } header: {
                Text("Alerts")
            }
        }
        .onAppear {
            if loggedIn {
                getStreamTitle()
            }
        }
        .navigationTitle("Twitch")
    }
}
