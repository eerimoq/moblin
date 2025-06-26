import SwiftUI

struct StreamWizardTwitchSettingsView: View {
    @EnvironmentObject private var model: Model
    @ObservedObject var createStreamWizard: CreateStreamWizard

    private func nextDisabled() -> Bool {
        return createStreamWizard.twitchChannelName.trim().isEmpty
    }

    private func onLoginComplete() {
        createStreamWizard.twitchChannelName = createStreamWizard.twitchStream.twitchChannelName
        createStreamWizard.twitchChannelId = createStreamWizard.twitchStream.twitchChannelId
        createStreamWizard.twitchAccessToken = createStreamWizard.twitchStream.twitchAccessToken
        createStreamWizard.twitchLoggedIn = createStreamWizard.twitchStream.twitchLoggedIn
        TwitchApi(createStreamWizard.twitchAccessToken, model.urlSession)
            .getStreamKey(broadcasterId: createStreamWizard.twitchChannelId) { streamKey in
                if let streamKey {
                    createStreamWizard.directStreamKey = streamKey
                }
            }
    }

    var body: some View {
        Form {
            Section {
                if createStreamWizard.twitchStream.twitchAccessToken.isEmpty {
                    Button {
                        createStreamWizard.showTwitchAuth = true
                        model.twitchLogin(stream: createStreamWizard.twitchStream) {
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
                        model.twitchLogout(stream: createStreamWizard.twitchStream)
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
                TextField("MyChannel", text: $createStreamWizard.twitchChannelName)
                    .disableAutocorrection(true)
            } header: {
                Text("Channel name")
            }
            Section {
                TextField("908123903", text: $createStreamWizard.twitchChannelId)
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
                NavigationLink {
                    StreamWizardNetworkSetupSettingsView(
                        createStreamWizard: createStreamWizard,
                        platform: String(localized: "Twitch")
                    )
                } label: {
                    WizardNextButtonView()
                }
                .disabled(nextDisabled())
            }
        }
        .sheet(isPresented: $createStreamWizard.showTwitchAuth) {
            VStack {
                HStack {
                    Spacer()
                    Button {
                        createStreamWizard.showTwitchAuth = false
                    } label: {
                        Text("Close").padding()
                    }
                }
                ScrollView {
                    TwitchAuthView(twitchAuth: model.twitchAuth)
                        .frame(height: 2500)
                }
            }
        }
        .onAppear {
            createStreamWizard.platform = .twitch
            createStreamWizard.name = "Twitch"
            createStreamWizard.twitchStream.twitchAccessToken = ""
        }
        .navigationTitle("Twitch")
        .toolbar {
            CreateStreamWizardToolbar(createStreamWizard: createStreamWizard)
        }
    }
}
