import SwiftUI

struct StreamWizardKickSettingsView: View {
    @EnvironmentObject private var model: Model

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
            model.wizardName = "Kick"
        }
        .navigationTitle("Kick")
        .toolbar {
            CreateStreamWizardToolbar()
        }
    }
}
