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
                NavigationLink(destination: StreamWizardCreateSettingsView()) {
                    HStack {
                        Spacer()
                        Text("Next")
                            .foregroundColor(.accentColor)
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Direct")
        .toolbar {
            CreateStreamWizardToolbar()
        }
    }
}
