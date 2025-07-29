import SwiftUI

struct StreamWizardYouTubeSettingsView: View {
    @EnvironmentObject private var model: Model
    @ObservedObject var createStreamWizard: CreateStreamWizard

    var body: some View {
        Form {
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
        }
        .navigationTitle("YouTube")
        .toolbar {
            CreateStreamWizardToolbar(createStreamWizard: createStreamWizard)
        }
    }
}
