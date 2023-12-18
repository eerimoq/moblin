import SwiftUI

struct StreamWizardKickSettingsView: View {
    @EnvironmentObject private var model: Model

    var body: some View {
        VStack {
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
            }
            NavigationLink(destination: StreamWizardNetworkSetupSettingsView(platform: "Kick")) {
                Text("Next")
                    .padding()
            }
            .disabled(model.wizardKickChatroomId.isEmpty)
            Spacer()
        }
        .navigationTitle("Kick")
        .toolbar {
            CreateStreamWizardToolbar()
        }
    }
}
