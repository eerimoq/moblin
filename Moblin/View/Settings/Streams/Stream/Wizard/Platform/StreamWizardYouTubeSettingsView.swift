import SwiftUI

struct StreamWizardYouTubeSettingsView: View {
    let model: Model
    @ObservedObject var createStreamWizard: CreateStreamWizard
    @ObservedObject var youTubeStream: SettingsStream

    var body: some View {
        Form {
            Section {
                if youTubeStream.youTubeAuthState == nil {
                    TextButtonView("Login") {
                        model.youTubeSignIn(stream: youTubeStream)
                    }
                } else {
                    TextButtonView("Logout") {
                        model.youTubeSignOut(stream: youTubeStream)
                    }
                }
            } footer: {
                Text("Optional, but simplifies the setup.")
            }
            Section {
                TextField(String("@erimo144"), text: $createStreamWizard.youTubeHandle)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            } header: {
                Text("Channel handle")
            } footer: {
                Text("Only needed for chat.")
            }
            Section {
                NavigationLink {
                    StreamWizardNetworkSetupSettingsView(
                        model: model,
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
            createStreamWizard.name = makeUniqueName(name: String(localized: "YouTube"),
                                                     existingNames: model.database.streams)
            createStreamWizard.directIngest = "rtmp://a.rtmp.youtube.com/live2"
            youTubeStream.youTubeAuthState = nil
        }
        .navigationTitle("YouTube")
        .toolbar {
            CreateStreamWizardToolbar(createStreamWizard: createStreamWizard)
        }
    }
}
