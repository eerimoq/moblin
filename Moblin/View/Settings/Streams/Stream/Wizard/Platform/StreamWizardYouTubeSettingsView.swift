import SwiftUI

struct StreamWizardYouTubeSettingsView: View {
    @EnvironmentObject private var model: Model

    var body: some View {
        Form {
            Section {
                TextField("gr230gkwpj03", text: $model.wizardYouTubeApiKey)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            } header: {
                Text("API key")
            } footer: {
                Text("Only needed for chat.")
            }
            Section {
                TextField("jo304F4gr", text: $model.wizardYouTubeVideoId)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            } header: {
                Text("Video id")
            } footer: {
                Text("Only needed for chat.")
            }
            Section {
                NavigationLink(
                    destination: StreamWizardNetworkSetupSettingsView(platform: String(localized: "YouTube"))
                ) {
                    WizardNextButtonView()
                }
            }
        }
        .onAppear {
            model.wizardPlatform = .youTube
            model.wizardName = "YouTube"
        }
        .navigationTitle("YouTube")
        .toolbar {
            CreateStreamWizardToolbar()
        }
    }
}
