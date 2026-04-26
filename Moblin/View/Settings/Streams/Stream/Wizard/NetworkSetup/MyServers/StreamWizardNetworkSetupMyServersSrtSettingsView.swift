import SwiftUI

struct StreamWizardNetworkSetupMyServersSrtSettingsView: View {
    let model: Model
    @ObservedObject var createStreamWizard: CreateStreamWizard
    @State var urlError = ""

    private func nextDisabled() -> Bool {
        return createStreamWizard.customSrtUrl.isEmpty
            || createStreamWizard.customSrtStreamId.isEmpty
            || !urlError.isEmpty
    }

    var body: some View {
        Form {
            StreamWizardSrtUrlSettingsView(createStreamWizard: createStreamWizard,
                                           urlError: $urlError)
            Section {
                NavigationLink {
                    StreamWizardObsRemoteControlSettingsView(
                        model: model,
                        createStreamWizard: createStreamWizard
                    )
                } label: {
                    WizardNextButtonView()
                }
                .disabled(nextDisabled())
            }
        }
        .onAppear {
            createStreamWizard.customProtocol = .srt
        }
        .navigationTitle("SRT(LA)")
        .toolbar {
            CreateStreamWizardToolbar(createStreamWizard: createStreamWizard)
        }
    }
}
