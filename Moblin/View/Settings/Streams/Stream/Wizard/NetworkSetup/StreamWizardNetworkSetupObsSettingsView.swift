import SwiftUI

struct StreamWizardNetworkSetupObsSettingsView: View {
    @EnvironmentObject private var model: Model
    @State var address = ""
    @State var port = ""

    var body: some View {
        Form {
            Section {
                TextField("213.33.45.132", text: $address)
            } header: {
                Text("OBS address")
            }
            Section {
                TextField("7000", text: $port)
            } header: {
                Text("OBS port")
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
