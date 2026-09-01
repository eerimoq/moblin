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
            if createStreamWizard.platform == .mobcam {
                Section {
                    Toggle("Auto go live", isOn: $createStreamWizard.autoGoLive)
                } footer: {
                    AutoGoLiveFooterView()
                }
            } else if !isMac() {
                Section {
                    Toggle("Background streaming", isOn: $createStreamWizard.backgroundStreaming)
                } footer: {
                    BackgroundStreamingFooterView()
                }
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
