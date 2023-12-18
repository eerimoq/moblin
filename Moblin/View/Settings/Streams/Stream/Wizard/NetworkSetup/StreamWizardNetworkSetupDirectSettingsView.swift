import SwiftUI

struct StreamWizardNetworkSetupDirectSettingsView: View {
    @State var ingest = ""
    @State var streamKey = ""

    var body: some View {
        VStack(alignment: .leading) {
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
            }
        }
    }
}
