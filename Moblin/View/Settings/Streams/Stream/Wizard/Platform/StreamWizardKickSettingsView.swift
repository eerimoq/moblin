import SwiftUI

struct StreamWizardKickSettingsView: View {
    @EnvironmentObject private var model: Model
    @ObservedObject var createStreamWizard: CreateStreamWizard

    private func channelName() -> String {
        return createStreamWizard.kickChannelName.trim()
    }

    private func nextDisabled() -> Bool {
        return channelName().isEmpty
    }

    var body: some View {
        Form {
            Section {
                TextField("MyChannel", text: $createStreamWizard.kickChannelName)
                    .disableAutocorrection(true)
            } header: {
                Text("Channel name")
            }
            Section {
                NavigationLink {
                    StreamWizardNetworkSetupSettingsView(
                        createStreamWizard: createStreamWizard,
                        platform: String(localized: "Kick")
                    )
                } label: {
                    WizardNextButtonView()
                }
                .disabled(nextDisabled())
            }
        }
        .onAppear {
            createStreamWizard.platform = .kick
            createStreamWizard.name = makeUniqueName(name: String(localized: "Kick"),
                                                     existingNames: model.database.streams)
            createStreamWizard.directIngest = ""
        }
        .navigationTitle("Kick")
        .toolbar {
            CreateStreamWizardToolbar(createStreamWizard: createStreamWizard)
        }
    }
}
