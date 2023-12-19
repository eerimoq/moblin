import SwiftUI

struct StreamWizardNetworkSetupBelaboxSettingsView: View {
    @EnvironmentObject private var model: Model

    var body: some View {
        Form {
            Section {
                Text("Open belabox cloud page")
            }
            Section {
                HStack {
                    Spacer()
                    Button {
                        model.isPresentingWizard = false
                    } label: {
                        Text("Create")
                    }
                    Spacer()
                }
            }
        }
    }
}
