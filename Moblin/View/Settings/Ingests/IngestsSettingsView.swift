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
            }
        }
        .navigationTitle("Ingests")
    }
}
