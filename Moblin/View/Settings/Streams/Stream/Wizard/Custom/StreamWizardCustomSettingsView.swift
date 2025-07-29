import SwiftUI

struct StreamWizardCustomSettingsView: View {
    let model: Model
    @ObservedObject var createStreamWizard: CreateStreamWizard

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    StreamWizardCustomSrtSettingsView(createStreamWizard: createStreamWizard)
                } label: {
                    Text("SRT(LA)")
                }
                NavigationLink {
                    StreamWizardCustomRtmpSettingsView(createStreamWizard: createStreamWizard)
                } label: {
                    Text("RTMP(S)")
                }
                NavigationLink {
                    StreamWizardCustomRistSettingsView(createStreamWizard: createStreamWizard)
                } label: {
                    Text("RIST")
                }
            } header: {
                Text("Protocol")
            }
            Section {
                NavigationLink {
                    StreamWizardSummarySettingsView(createStreamWizard: createStreamWizard)
                } label: {
                    WizardSkipButtonView()
                }
            }
        }
        .onAppear {
            createStreamWizard.platform = .custom
            createStreamWizard.networkSetup = .none
            createStreamWizard.customProtocol = .none
            createStreamWizard.name = makeUniqueName(name: String(localized: "Custom"),
                                                     existingNames: model.database.streams)
        }
        .navigationTitle("Custom")
        .toolbar {
            CreateStreamWizardToolbar(createStreamWizard: createStreamWizard)
        }
    }
}
