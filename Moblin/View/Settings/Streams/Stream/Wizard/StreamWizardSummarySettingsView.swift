import SwiftUI

struct StreamWizardSummarySettingsView: View {
    @EnvironmentObject private var model: Model

    var body: some View {
        Form {
            Section {
                if model.wizardPlatform == .twitch {
                    Text("Some Twitch information")
                }
                if model.wizardPlatform == .kick {
                    Text("Some Kick information")
                }
                if model.wizardNotworkSetup == .obs {
                    Text("OBS")
                }
                if model.wizardNotworkSetup == .belaboxCloudObs {
                    Text("BELABOX cloud")
                }
                if model.wizardNotworkSetup == .direct {
                    Text("Direct")
                }
            }
            Section {
                TextField("Name", text: $model.wizardName)
            } header: {
                Text("Stream name")
            }
            Section {
                HStack {
                    Spacer()
                    Button {
                        model.createStreamFromWizard()
                        model.isPresentingWizard = false
                    } label: {
                        Text("Create")
                    }
                    Spacer()
                }
            }
        }
        .navigationTitle("Summary")
        .toolbar {
            CreateStreamWizardToolbar()
        }
    }
}
