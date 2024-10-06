import SwiftUI

struct StreamWizardAfreecaTvSettingsView: View {
    @EnvironmentObject private var model: Model

    var body: some View {
        Form {
            Section {
                TextField("MyChannel", text: $model.wizardAfreecaTvChannelName)
                    .disableAutocorrection(true)
            } header: {
                Text("Channel name")
            }
            Section {
                TextField("908123903", text: $model.wizardAfreecsTvCStreamId)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            } header: {
                Text("Video id")
            }
            Section {
                NavigationLink {
                    StreamWizardNetworkSetupSettingsView(platform: String(localized: "AfreecaTV"))
                } label: {
                    WizardNextButtonView()
                }
            }
        }
        .onAppear {
            model.wizardPlatform = .afreecaTv
            model.wizardName = "AfreecaTV"
        }
        .navigationTitle("AfreecaTV")
        .toolbar {
            CreateStreamWizardToolbar()
        }
    }
}
