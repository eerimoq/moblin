import SwiftUI

struct StreamWizardTwitchSettingsView: View {
    @EnvironmentObject private var model: Model

    var body: some View {
        Form {
            Section {
                TextField("MyChannel", text: $model.wizardTwitchChannelName)
            } header: {
                Text("Channel name")
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
                    WizardNextButtonView()
                }
                .disabled(model.wizardTwitchChannelName.isEmpty)
            }
        }
        .onAppear {
            model.wizardPlatform = .twitch
        }
        .navigationTitle("Twitch")
        .toolbar {
            CreateStreamWizardToolbar()
        }
    }
}
