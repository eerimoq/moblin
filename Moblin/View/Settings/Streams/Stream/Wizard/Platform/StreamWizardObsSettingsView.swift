import SwiftUI

struct StreamWizardObsSettingsView: View {
    let model: Model
    @ObservedObject var createStreamWizard: CreateStreamWizard

    var body: some View {
        StreamWizardNetworkSetupObsSettingsView(model: model, createStreamWizard: createStreamWizard)
            .onAppear {
                createStreamWizard.platform = .obs
                createStreamWizard.name = makeUniqueName(name: String(localized: "OBS"),
                                                         existingNames: model.database.streams)
            }
    }
}
