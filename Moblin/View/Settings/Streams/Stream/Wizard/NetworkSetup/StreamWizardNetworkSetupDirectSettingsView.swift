import SwiftUI

struct StreamWizardNetworkSetupDirectSettingsView: View {
    @EnvironmentObject private var model: Model

    private func isDisabled() -> Bool {
        return model.wizardDirectIngress.isEmpty || model.wizardDirectStreamKey.isEmpty
    }

    var body: some View {
        Form {
            Section {
                TextField("rtmp://foobar", text: $model.wizardDirectIngress)
            } header: {
                Text("Nearby ingest")
            }
            Section {
                TextField("9fh260lbtb730gy73gkd", text: $model.wizardDirectStreamKey)
            } header: {
                Text("Stream key")
            }
            Section {
                NavigationLink(destination: StreamWizardGeneralSettingsView()) {
                    WizardNextButtonView()
                }
                .disabled(isDisabled())
            }
        }
        .onAppear {
            model.wizardNotworkSetup = .direct
        }
        .navigationTitle("Direct")
        .toolbar {
            CreateStreamWizardToolbar()
        }
    }
}
