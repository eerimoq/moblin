import SwiftUI

struct StreamWizardGeneralSettingsView: View {
    @EnvironmentObject private var model: Model
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
                Section {
                    Toggle("Background streaming", isOn: $createStreamWizard.backgroundStreaming)
                } footer: {
                    VStack(alignment: .leading) {
                        Text("Live stream and record when the app is in background mode.")
                        Text("")
                        Text("""
                        Built-in and USB cameras will freeze when the app is in \
                        background mode. Apple limitation. 😢
                        """)
                    }
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
