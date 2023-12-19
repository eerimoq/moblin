import SwiftUI

struct StreamWizardTwitchSettingsView: View {
    @EnvironmentObject private var model: Model

    var body: some View {
        Form {
            Section {
                TextField("MyChannel", text: $model.wizardTwitchChannelName)
            } header: {
                Text("Channel name")
            } footer: {
                Text("The name of your channel.")
            }
            Section {
                TextField("908123903", text: $model.wizardTwitchChannelId)
            } header: {
                Text("Channel id")
            } footer: {
                VStack(alignment: .leading) {
                    Text("Needed for your emotes.")
                    Text("")
                    Text(
                        """
                        A large number. Use developer tools (F11) \
                        in your browser. Look at websocket messages.
                        """
                    )
                }
            }
            Section {
                NavigationLink(destination: StreamWizardNetworkSetupSettingsView(platform: "Twitch")) {
                    HStack {
                        Spacer()
                        Text("Next")
                            .foregroundColor(.accentColor)
                        Spacer()
                    }
                }
                .disabled(model.wizardTwitchChannelName.isEmpty)
            }
        }
        .navigationTitle("Twitch")
        .toolbar {
            CreateStreamWizardToolbar()
        }
    }
}
