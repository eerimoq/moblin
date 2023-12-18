import SwiftUI

struct StreamWizardTwitchSettingsView: View {
    @EnvironmentObject private var model: Model

    var body: some View {
        VStack {
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
            }
            NavigationLink(destination: StreamWizardNetworkSetupSettingsView(platform: "Twitch")) {
                Text("Next")
                    .padding()
            }
            .disabled(model.wizardTwitchChannelName.isEmpty)
            Spacer()
        }
        .navigationTitle("Twitch")
        .toolbar {
            CreateStreamWizardToolbar()
        }
    }
}
