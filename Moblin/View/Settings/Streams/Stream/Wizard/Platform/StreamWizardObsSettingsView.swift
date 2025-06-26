import SwiftUI

struct StreamWizardObsSettingsView: View {
    @ObservedObject var createStreamWizard: CreateStreamWizard

    var body: some View {
        StreamWizardNetworkSetupObsSettingsView(createStreamWizard: createStreamWizard)
            .onAppear {
                createStreamWizard.platform = .obs
                createStreamWizard.name = "OBS"
            }
    }
}
