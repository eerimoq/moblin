import SwiftUI

struct IngestsSettingsView: View {
    let model: Model
    @ObservedObject var database: Database

    var body: some View {
        Form {
            Section {
                RtmpServerSettingsView(rtmpServer: database.rtmpServer)
                SrtlaServerSettingsView(srtlaServer: database.srtlaServer)
                SrtClientSettingsView(srtClient: database.srtClient)
                RistServerSettingsView(ristServer: database.ristServer)
                RtspClientSettingsView(rtspClient: database.rtspClient)
                WhipServerSettingsView(whipServer: database.whipServer)
                WhepClientSettingsView(whepClient: database.whepClient)
                if #available(iOS 26, *), false {
                    #if !targetEnvironment(macCatalyst)
                    NavigationLink {
                        WiFiAwareSettingsView(model: model, wiFiAware: database.wiFiAware)
                    } label: {
                        Text(String("WiFi Aware"))
                    }
                    #endif
                }
            }
            Section {
                Toggle("Software video decoding", isOn: $database.ingestsSoftwareVideoDecoding)
                    .onChange(of: database.ingestsSoftwareVideoDecoding) { _ in
                        model.reloadIngests()
                    }
            } footer: {
                VStack(alignment: .leading) {
                    Text("""
                    Decode ingested video on the CPU instead of using the hardware video decoder. \
                    Uses more CPU, battery and generates more heat, but can decode video the hardware \
                    decoder does not support and allows decoding more streams at the same time.
                    """)
                    Text("")
                    Text("Only enable this if hardware video decoding does not work.")
                }
            }
        }
        .navigationTitle("Ingests")
    }
}
