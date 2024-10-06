import SwiftUI

struct StreamWizardYouTubeSettingsView: View {
    @EnvironmentObject private var model: Model

    var body: some View {
        Form {
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
                NavigationLink {
                    StreamWizardNetworkSetupSettingsView(platform: String(localized: "YouTube"))
                } label: {
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
