import SwiftUI

struct StreamWizardKickSettingsView: View {
    @EnvironmentObject private var model: Model

    var body: some View {
        Form {
            Section {
                TextField("90812903", text: $model.wizardKickChatroomId)
            } header: {
                Text("Chatroom id")
            } footer: {
                VStack(alignment: .leading) {
                    Text("Needed for chat.")
                    Text("")
                    Text(
                        """
                        Find your chatroom id at https://kick.com/api/v1/channels/my_user. \
                        Replace my_user with your user.
                        """
                    )
                }
            }
            Section {
                NavigationLink(destination: StreamWizardNetworkSetupSettingsView(platform: "Kick")) {
                    HStack {
                        Spacer()
                        Text("Next")
                        Spacer()
                    }
                }
                .disabled(model.wizardKickChatroomId.isEmpty)
            }
        }
        .navigationTitle("Kick")
        .toolbar {
            CreateStreamWizardToolbar()
        }
    }
}
