import SwiftUI

struct StreamWizardObsSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var createStreamWizard: CreateStreamWizard

    var body: some View {
        StreamWizardNetworkSetupObsSettingsView(createStreamWizard: createStreamWizard)
            .onAppear {
                createStreamWizard.platform = .obs
                createStreamWizard.name = makeUniqueName(name: String(localized: "OBS"),
                                                         existingNames: model.database.streams)
            }
    }
}
