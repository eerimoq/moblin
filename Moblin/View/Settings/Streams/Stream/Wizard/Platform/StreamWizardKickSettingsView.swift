import SwiftUI

struct StreamWizardKickSettingsView: View {
    let model: Model
    @ObservedObject var createStreamWizard: CreateStreamWizard
    @State private var fetchingChannelInfo: Bool = false
    @State private var fetchChannelInfoFailed: Bool = false

    private func nextDisabled() -> Bool {
        return createStreamWizard.kickChannelName.trim().isEmpty
            || fetchingChannelInfo
            || createStreamWizard.kickChannelId == nil
    }

    private func handleChannelInfo(_ channelInfo: KickChannel) {
        fetchingChannelInfo = false
        fetchChannelInfoFailed = false
        createStreamWizard.kickChannelId = String(channelInfo.chatroom.id)
        createStreamWizard.kickSlug = channelInfo.slug
        createStreamWizard.kickChatroomChannelId = String(channelInfo.chatroom.channel_id)
        createStreamWizard.kickChannelName = channelInfo.slug
    }

    private func fetchChannelInfo() {
        fetchingChannelInfo = true
        fetchChannelInfoFailed = false
        let channelName = createStreamWizard.kickChannelName.trim()
        getKickChannelInfo(channelName: channelName) { channelInfo in
            if let channelInfo {
                handleChannelInfo(channelInfo)
            } else {
                let altName: String
                if channelName.contains("_") {
                    altName = channelName.replacingOccurrences(of: "_", with: "-")
                } else if channelName.contains("-") {
                    altName = channelName.replacingOccurrences(of: "-", with: "_")
                } else {
                    fetchingChannelInfo = false
                    fetchChannelInfoFailed = true
                    return
                }
                getKickChannelInfo(channelName: altName) { retryChannelInfo in
                    if let retryChannelInfo {
                        handleChannelInfo(retryChannelInfo)
                    } else {
                        fetchingChannelInfo = false
                        fetchChannelInfoFailed = true
                    }
                }
            }
        }
    }

    private func onLoginComplete() {
        createStreamWizard.kickChannelName = createStreamWizard.kickStream.kickChannelName
        createStreamWizard.kickAccessToken = createStreamWizard.kickStream.kickAccessToken
        createStreamWizard.kickLoggedIn = createStreamWizard.kickStream.kickLoggedIn
        createStreamWizard.kickChannelId = createStreamWizard.kickStream.kickChannelId
        createStreamWizard.kickSlug = createStreamWizard.kickStream.kickSlug
        createStreamWizard.kickChatroomChannelId = createStreamWizard.kickStream.kickChatroomChannelId
    }

    var body: some View {
        Form {
            Section {
                if createStreamWizard.kickStream.kickAccessToken.isEmpty {
                    TextButtonView("Login") {
                        createStreamWizard.showKickAuth = true
                        model.kickLogin(stream: createStreamWizard.kickStream) {
                            onLoginComplete()
                        }
                    }
                } else {
                    TextButtonView("Logout") {
                        model.kickLogout(stream: createStreamWizard.kickStream)
                    }
                }
            } footer: {
                Text("Optional, but simplifies the setup.")
            }
            Section {
                TextField("MyChannel", text: $createStreamWizard.kickChannelName)
                    .disableAutocorrection(true)
                    .onChange(of: createStreamWizard.kickChannelName) { _ in
                        if createStreamWizard.kickSlug != createStreamWizard.kickChannelName {
                            createStreamWizard.kickChannelId = nil
                            createStreamWizard.kickSlug = nil
                            createStreamWizard.kickChatroomChannelId = nil
                            fetchChannelInfoFailed = false
                        }
                    }
                    .onSubmit {
                        fetchChannelInfo()
                    }
            } header: {
                Text("Channel name")
            } footer: {
                if fetchingChannelInfo {
                    Text("Fetching channel info...")
                } else if fetchChannelInfoFailed {
                    Text("Channel not found on kick.com.")
                        .foregroundStyle(.red)
                }
            }
            Section {
                NavigationLink {
                    StreamWizardNetworkSetupSettingsView(
                        model: model,
                        createStreamWizard: createStreamWizard,
                        platform: String(localized: "Kick")
                    )
                } label: {
                    WizardNextButtonView()
                }
                .disabled(nextDisabled())
            }
        }
        .sheet(isPresented: $createStreamWizard.showKickAuth) {
            KickLoginView(presenting: $createStreamWizard.showKickAuth) { accessToken in
                model.kickAuthOnComplete?(accessToken)
            }
        }
        .onAppear {
            createStreamWizard.platform = .kick
            createStreamWizard.name = makeUniqueName(name: String(localized: "Kick"),
                                                     existingNames: model.database.streams)
            createStreamWizard.directIngest = ""
            createStreamWizard.kickStream.kickAccessToken = ""
        }
        .navigationTitle("Kick")
        .toolbar {
            CreateStreamWizardToolbar(createStreamWizard: createStreamWizard)
        }
    }
}
