import SwiftUI

struct StreamWizardNetworkSetupDirectSettingsView: View {
    @EnvironmentObject private var model: Model

    private func isDisabled() -> Bool {
        return model.wizardDirectIngest.isEmpty || model.wizardDirectStreamKey.isEmpty
    }

    var body: some View {
        Form {
            if model.wizardPlatform == .twitch {
                Section {
                    TextField("rtmp://arn03.contribute.live-video.net/app", text: $model.wizardDirectIngest)
                        .disableAutocorrection(true)
                } header: {
                    Text("Nearby ingest endpoint")
                } footer: {
                    Text("""
                    Copy a nearby ingest endpoint from \
                    https://help.twitch.tv/s/twitch-ingest-recommendation
                    """)
                }
                Section {
                    TextField(
                        "live_48950233_okF4f455GRWEF443fFr23GRbt5rEv",
                        text: $model.wizardDirectStreamKey
                    )
                    .disableAutocorrection(true)
                } header: {
                    Text("Stream key")
                } footer: {
                    Text(
                        """
                        Copy your Stream key from \
                        https://dashboard.twitch.tv/u/\(model.wizardTwitchChannelName)/settings/stream \
                        (requires login).
                        """
                    )
                }
            } else if model.wizardPlatform == .kick {
                Section {
                    TextField(
                        "rtmps://fa723fc1b171.global-contribute.live-video.net",
                        text: $model.wizardDirectIngest
                    )
                    .disableAutocorrection(true)
                } header: {
                    Text("Stream URL")
                } footer: {
                    Text(
                        "Copy the Stream URL from https://kick.com/dashboard/settings/stream (requires login)."
                    )
                }
                Section {
                    TextField(
                        "sk_us-west-2_okfef49k34k_34g59gGDDHGHSREj754gYJYTJERH",
                        text: $model.wizardDirectStreamKey
                    )
                    .disableAutocorrection(true)
                } header: {
                    Text("Stream key")
                } footer: {
                    Text(
                        "Copy your Stream ket from https://kick.com/dashboard/settings/stream (requires login)."
                    )
                }
            }
            Section {
                NavigationLink(destination: StreamWizardGeneralSettingsView()) {
                    WizardNextButtonView()
                }
                .disabled(isDisabled())
            }
        }
        .onAppear {
            model.wizardNetworkSetup = .direct
        }
        .navigationTitle("Direct")
        .toolbar {
            CreateStreamWizardToolbar()
        }
    }
}
