import SwiftUI

struct StreamWizardYouTubeSettingsView: View {
    @EnvironmentObject private var model: Model

    var body: some View {
        Form {
            Section {
                TextField("gr230gkwpj03", text: $model.wizardYouTubeApiKey)
                    .disableAutocorrection(true)
            } header: {
                Text("API key")
            }
            Section {
                TextField("jo304F4gr", text: $model.wizardYouTubeVideoId)
                    .disableAutocorrection(true)
            } header: {
                Text("Video id")
            }
            Section {
                NavigationLink(destination: StreamWizardNetworkSetupSettingsView(platform: "YouTube")) {
                    WizardNextButtonView()
                }
            }
        }
        .onAppear {
            model.wizardPlatform = .youTube
        }
        .navigationTitle("YouTube")
        .toolbar {
            CreateStreamWizardToolbar()
        }
    }
}
