import SwiftUI

struct StreamWizardNetworkSetupDirectSettingsView: View {
    @EnvironmentObject private var model: Model

    private func isDisabled() -> Bool {
        return model.wizardDirectIngest.isEmpty || model.wizardDirectStreamKey.isEmpty
    }

    private func twitchStreamKeyUrl() -> String {
        return "https://dashboard.twitch.tv/u/\(model.wizardTwitchChannelName.trim())/settings/stream"
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
                    Copy from \
                    https://help.twitch.tv/s/twitch-ingest-recommendation. Remove {stream_key}.
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
                    HStack(spacing: 0) {
                        Text("Copy from ")
                        Link(twitchStreamKeyUrl(), destination: URL(string: twitchStreamKeyUrl())!)
                            .font(.footnote)
                        Text(" (requires login).")
                    }
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
                        "Copy from https://kick.com/dashboard/settings/stream (requires login)."
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
                        "Copy from https://kick.com/dashboard/settings/stream (requires login)."
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
