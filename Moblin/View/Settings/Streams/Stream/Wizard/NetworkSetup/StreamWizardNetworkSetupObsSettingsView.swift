import SwiftUI

struct StreamWizardNetworkSetupObsSettingsView: View {
    @State var address = ""
    @State var port = ""

    var body: some View {
        VStack(alignment: .leading) {
            Text("Some information about how to setup OBS Media Source")
                .padding()
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
            }
        }
    }
}
