import SwiftUI

struct StreamWizardCustomSettingsView: View {
    @EnvironmentObject private var model: Model

    var body: some View {
        Form {
            VStack(alignment: .leading) {
                Text("Configure the stream after the wizard ends.")
            }
            Section {
                NavigationLink(destination: StreamWizardSummarySettingsView()) {
                    WizardNextButtonView()
                }
            }
        }
        .onAppear {
            model.wizardPlatform = .custom
            model.wizardNetworkSetup = .none
            model.wizardName = "Custom"
        }
        .navigationTitle("Custom")
        .toolbar {
            CreateStreamWizardToolbar()
        }
    }
}
