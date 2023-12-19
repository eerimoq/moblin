import SwiftUI

struct StreamWizardKickSettingsView: View {
    @EnvironmentObject private var model: Model

    private func url() -> String {
        return "https://kick.com/api/v1/channels/\(channelName())"
    }

    private func channelName() -> String {
        return model.wizardKickChannelName.trim()
    }

    var body: some View {
        Form {
            Section {
                TextField("MyChannel", text: $model.wizardKickChannelName)
            } header: {
                Text("Channel name")
            }
            Section {
                TextField("90812903", text: $model.wizardKickChatroomId)
            } header: {
                Text("Chatroom id")
            } footer: {
                VStack(alignment: .leading) {
                    Text("Needed for chat.")
                    Text("")
                    if !channelName().isEmpty, let url = URL(string: url()) {
                        HStack(spacing: 0) {
                            Text("Find your chatroom id ")
                            Link("here", destination: url)
                                .font(.footnote)
                            Text(".")
                        }
                    }
                }
            }
            Section {
                NavigationLink(destination: StreamWizardNetworkSetupSettingsView(platform: "Kick")) {
                    WizardNextButtonView()
                }
                .disabled(model.wizardKickChannelName.isEmpty)
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
