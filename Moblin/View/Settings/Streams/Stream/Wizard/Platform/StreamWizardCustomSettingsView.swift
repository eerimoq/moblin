import SwiftUI

struct StreamWizardCustomSettingsView: View {
    @EnvironmentObject private var model: Model

    var body: some View {
        Form {
            VStack(alignment: .leading) {
                Text("Creating a stream with default settings.")
                Text("")
                Text("You must configure it after the wizard ends.")
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
