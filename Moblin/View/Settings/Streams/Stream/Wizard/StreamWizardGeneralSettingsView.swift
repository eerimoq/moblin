import SwiftUI

struct StreamWizardGeneralSettingsView: View {
    let model: Model
    @ObservedObject var createStreamWizard: CreateStreamWizard

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $createStreamWizard.name)
            } header: {
                Text("Stream name")
                    .disableAutocorrection(true)
            }
            if !isMac() {
                BackgroundStreamingToggleView(enabled: $createStreamWizard.backgroundStreaming)
            }
            Section {
                TextButtonView("Create") {
                    model.createStreamFromWizard()
                    createStreamWizard.presenting = false
                    createStreamWizard.presentingSetup = false
                }
                .disabled(createStreamWizard.name.isEmpty)
            }
        }
        .navigationTitle("General")
        .toolbar {
            CreateStreamWizardToolbar(createStreamWizard: createStreamWizard)
        }
    }
}
