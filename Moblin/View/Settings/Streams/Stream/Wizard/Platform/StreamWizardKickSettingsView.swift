import SwiftUI

struct StreamWizardKickSettingsView: View {
    @EnvironmentObject private var model: Model

    private func url() -> String {
        return "https://kick.com/api/v1/channels/\(channelName())"
    }

    private func channelName() -> String {
        return model.wizardKickChannelName.trim()
    }

    private func nextDisabled() -> Bool {
        return channelName().isEmpty
    }

    var body: some View {
        Form {
            Section {
                TextField("MyChannel", text: $model.wizardKickChannelName)
                    .disableAutocorrection(true)
            } header: {
                Text("Channel name")
            }
            Section {
                TextField("18529305", text: $model.wizardKickChatroomId)
                    .disableAutocorrection(true)
            } header: {
                Text("Chatroom id")
            } footer: {
                VStack(alignment: .leading) {
                    Text("Needed for chat.")
                    Text("")
                    if !channelName().isEmpty, let url = URL(string: url()) {
                        HStack(spacing: 0) {
                            Text("Find your chatroom id at ")
                            Link(url.absoluteString, destination: url)
                                .font(.footnote)
                            Text(".")
                        }
                        Text("")
                        Text("""
                        Search for \"chatroom\" on that page. 18529305 is the chatroom id in \
                        the example screenshot below.
                        """)
                        Text("")
                        HStack {
                            Spacer()
                            Image("KickChatroomId")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: 200)
                            Spacer()
                        }
                    }
                }
            }
            Section {
                NavigationLink(
                    destination: StreamWizardNetworkSetupSettingsView(platform: String(localized: "Kick"))
                ) {
                    WizardNextButtonView()
                }
                .disabled(nextDisabled())
            }
        }
        .onAppear {
            model.wizardPlatform = .kick
        }
        .navigationTitle("Kick")
        .toolbar {
            CreateStreamWizardToolbar()
        }
    }
}
