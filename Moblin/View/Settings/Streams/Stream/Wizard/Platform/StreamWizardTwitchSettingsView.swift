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
        TwitchApi(createStreamWizard.twitchAccessToken)
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
                    TextButtonView("Login") {
                        createStreamWizard.showTwitchAuth = true
                        model.twitchLogin(stream: createStreamWizard.twitchStream) {
                            onLoginComplete()
                        }
                    }
                } else {
                    TextButtonView("Logout") {
                        model.twitchLogout(stream: createStreamWizard.twitchStream)
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
            ZStack {
                ScrollView {
                    TwitchAuthView(twitchAuth: model.twitchAuth)
                        .frame(height: 2500)
                }
                CloseButtonTopRightView {
                    createStreamWizard.showTwitchAuth = false
                }
            }
        }
        .onAppear {
            createStreamWizard.platform = .twitch
            createStreamWizard.name = makeUniqueName(name: String(localized: "Twitch"),
                                                     existingNames: model.database.streams)
            createStreamWizard.directIngest = "rtmp://ingest.global-contribute.live-video.net/app"
            createStreamWizard.twitchStream.twitchAccessToken = ""
        }
        .navigationTitle("Twitch")
        .toolbar {
            CreateStreamWizardToolbar(createStreamWizard: createStreamWizard)
        }
    }
}
