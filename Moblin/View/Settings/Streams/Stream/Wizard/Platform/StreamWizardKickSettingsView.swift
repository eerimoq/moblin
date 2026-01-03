import SwiftUI

struct StreamWizardKickSettingsView: View {
    @EnvironmentObject private var model: Model
    @ObservedObject var createStreamWizard: CreateStreamWizard

    private func nextDisabled() -> Bool {
        return createStreamWizard.kickChannelName.trim().isEmpty
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
            } header: {
                Text("Channel name")
            }
            Section {
                NavigationLink {
                    StreamWizardNetworkSetupSettingsView(
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
