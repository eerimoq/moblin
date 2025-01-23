import SwiftUI

struct StreamWizardObsSettingsView: View {
    @EnvironmentObject private var model: Model

    var body: some View {
        StreamWizardNetworkSetupObsSettingsView()
            .onAppear {
                model.wizardPlatform = .obs
                model.wizardName = "OBS"
            }
    }
}
