import SwiftUI

struct StreamWizardYouTubeSettingsView: View {
    @EnvironmentObject private var model: Model
    @ObservedObject var createStreamWizard: CreateStreamWizard

    var body: some View {
        Form {
            Section {
                TextField("jo304F4gr", text: $createStreamWizard.youTubeVideoId)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            } header: {
                Text("Video id")
            } footer: {
                Text("Only needed for chat.")
            }
            Section {
                NavigationLink {
                    StreamWizardNetworkSetupSettingsView(
                        createStreamWizard: createStreamWizard,
                        platform: String(localized: "YouTube")
                    )
                } label: {
                    WizardNextButtonView()
                }
            }
        }
        .onAppear {
            createStreamWizard.platform = .youTube
            createStreamWizard.name = "YouTube"
            createStreamWizard.directIngest = "rtmp://a.rtmp.youtube.com/live2"
        }
        .navigationTitle("YouTube")
        .toolbar {
            CreateStreamWizardToolbar(createStreamWizard: createStreamWizard)
        }
    }
}
