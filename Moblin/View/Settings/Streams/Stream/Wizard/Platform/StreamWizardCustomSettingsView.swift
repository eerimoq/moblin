import SwiftUI

struct StreamWizardCustomSettingsView: View {
    @EnvironmentObject private var model: Model

    var body: some View {
        Form {
            VStack(alignment: .leading) {
                Text("Custom streams must be configured after the wizard ends.")
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
        }
        .navigationTitle("Custom")
        .toolbar {
            CreateStreamWizardToolbar()
        }
    }
}
