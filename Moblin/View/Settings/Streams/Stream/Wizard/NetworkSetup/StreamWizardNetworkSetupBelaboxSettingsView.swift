import SwiftUI

struct StreamWizardNetworkSetupBelaboxSettingsView: View {
    @EnvironmentObject private var model: Model

    var body: some View {
        Form {
            Section {
                Text("Open belabox cloud page")
            }
            Section {
                NavigationLink(destination: StreamWizardGeneralSettingsView()) {
                    WizardNextButtonView()
                }
            }
        }
        .onAppear {
            model.wizardNetworkSetup = .belaboxCloudObs
        }
        .navigationTitle("BELABOX cloud and OBS")
        .toolbar {
            CreateStreamWizardToolbar()
        }
    }
}
