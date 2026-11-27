import SwiftUI

struct StreamWizardChzzkSettingsView: View {
    let model: Model
    @ObservedObject var createStreamWizard: CreateStreamWizard

    var body: some View {
        Form {
            Section {
                ChzzkSetupGuideLink()
            }
            Section {
                TextField("Channel id", text: $createStreamWizard.chzzkChannelId)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            } header: {
                Text("Channel id")
            } footer: {
                ChzzkChannelIdFooterView()
            }
            Section {
                NavigationLink {
                    StreamWizardNetworkSetupSettingsView(
                        model: model,
                        createStreamWizard: createStreamWizard,
                        platform: String(localized: "CHZZK")
                    )
                } label: {
                    WizardNextButtonView()
                }
            }
        }
        .onAppear {
            if createStreamWizard.platform != .chzzk {
                createStreamWizard.platform = .chzzk
                createStreamWizard.name = makeUniqueName(name: String(localized: "CHZZK"),
                                                         existingNames: model.database.streams)
            }
        }
        .navigationTitle("CHZZK")
        .toolbar {
            CreateStreamWizardToolbar(createStreamWizard: createStreamWizard)
        }
    }
}
