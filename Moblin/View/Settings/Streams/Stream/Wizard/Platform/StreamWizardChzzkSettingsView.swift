import SwiftUI

struct StreamWizardChzzkSettingsView: View {
    let model: Model
    @ObservedObject var createStreamWizard: CreateStreamWizard

    var body: some View {
        StreamWizardNetworkSetupSettingsView(
            model: model,
            createStreamWizard: createStreamWizard,
            platform: String(localized: "CHZZK")
        )
        .onAppear {
            if createStreamWizard.platform != .chzzk {
                createStreamWizard.platform = .chzzk
                createStreamWizard.name = makeUniqueName(name: String(localized: "CHZZK"),
                                                         existingNames: model.database.streams)
            }
        }
    }
}
