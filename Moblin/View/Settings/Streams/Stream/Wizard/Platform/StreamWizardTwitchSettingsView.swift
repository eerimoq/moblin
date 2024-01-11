import SwiftUI

struct StreamWizardTwitchSettingsView: View {
    @EnvironmentObject private var model: Model

    private func nextDisabled() -> Bool {
        return model.wizardTwitchChannelName.trim().isEmpty
    }

    var body: some View {
        Form {
            Section {
                TextField("MyChannel", text: $model.wizardTwitchChannelName)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            } header: {
                Text("Channel name")
            }
            Section {
                TextField("908123903", text: $model.wizardTwitchChannelId)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            } header: {
                Text("Channel id")
            } footer: {
                VStack(alignment: .leading) {
                    Text("Needed for channel chat emotes and number of viewers.")
                    Text("")
                    Text(
                        """
                        Use https://streamscharts.com/tools/convert-username to convert your \
                        channel name to your channel id.
                        """
                    )
                }
            }
            Section {
                NavigationLink(
                    destination: StreamWizardNetworkSetupSettingsView(platform: String(localized: "Twitch"))
                ) {
                    WizardNextButtonView()
                }
                .disabled(nextDisabled())
            }
        }
        .onAppear {
            model.wizardPlatform = .twitch
            model.wizardName = "Twitch"
        }
        .navigationTitle("Twitch")
        .toolbar {
            CreateStreamWizardToolbar()
        }
    }
}
