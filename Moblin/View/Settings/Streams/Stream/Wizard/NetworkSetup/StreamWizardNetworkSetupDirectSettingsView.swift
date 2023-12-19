import SwiftUI

struct StreamWizardNetworkSetupDirectSettingsView: View {
    @EnvironmentObject private var model: Model
    @State var ingest = ""
    @State var streamKey = ""

    var body: some View {
        Form {
            Section {
                TextField("rtmp://foobar", text: $ingest)
            } header: {
                Text("Nearby ingest")
            }
            Section {
                TextField("23234234234234", text: $streamKey)
            } header: {
                Text("Stream key")
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
