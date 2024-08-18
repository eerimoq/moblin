import SwiftUI

struct StreamWizardTwitchSettingsView: View {
    @EnvironmentObject private var model: Model

    private func nextDisabled() -> Bool {
        return model.wizardTwitchChannelName.trim().isEmpty
    }

    private func onLoginComplete() {
        model.wizardTwitchChannelName = model.wizardTwitchStream.twitchChannelName
        model.wizardTwitchChannelId = model.wizardTwitchStream.twitchChannelId
        model.wizardTwitchAccessToken = model.wizardTwitchStream.twitchAccessToken!
        model.wizardTwitchLoggedIn = model.wizardTwitchStream.twitchLoggedIn!
        TwitchApi(accessToken: model.wizardTwitchAccessToken)
            .getStreamKey(userId: model.wizardTwitchChannelId) { streamKey in
                if let streamKey {
                    model.wizardDirectStreamKey = streamKey
                }
            }
    }

    var body: some View {
        Form {
            Section {
                if model.wizardTwitchStream.twitchAccessToken!.isEmpty {
                    Button {
                        model.wizardShowTwitchAuth = true
                        model.twitchLogin(stream: model.wizardTwitchStream) {
                            onLoginComplete()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text("Login")
                            Spacer()
                        }
                    }
                } else {
                    Button {
                        model.twitchLogout(stream: model.wizardTwitchStream)
                    } label: {
                        HStack {
                            Spacer()
                            Text("Logout")
                            Spacer()
                        }
                    }
                }
            } footer: {
                Text("Optional, but simplifies the setup.")
            }
            Section {
                TextField("MyChannel", text: $model.wizardTwitchChannelName)
                    .disableAutocorrection(true)
            } header: {
                Text("Channel name")
            }
            Section {
                TextField("908123903", text: $model.wizardTwitchChannelId)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            } header: {
                Text("Channel id")
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
            Section {
                NavigationLink(
                    destination: StreamWizardNetworkSetupSettingsView(platform: String(localized: "Twitch"))
                ) {
                    WizardNextButtonView()
                }
                .disabled(nextDisabled())
            }
        }
        .sheet(isPresented: $model.wizardShowTwitchAuth) {
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        model.wizardShowTwitchAuth = false
                    }, label: {
                        Text("Close").padding()
                    })
                }
                TwitchAuthView()
            }
        }
        .onAppear {
            model.wizardPlatform = .twitch
            model.wizardName = "Twitch"
            model.wizardTwitchStream.twitchAccessToken = ""
        }
        .navigationTitle("Twitch")
        .toolbar {
            CreateStreamWizardToolbar()
        }
    }
}
