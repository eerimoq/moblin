import SwiftUI

struct IngestsSettingsView: View {
    let model: Model
    let database: Database

    var body: some View {
        Form {
            Section {
                RtmpServerSettingsView(rtmpServer: database.rtmpServer)
                WhipServerSettingsView(whipServer: database.whipServer)
                SrtlaServerSettingsView(srtlaServer: database.srtlaServer)
                RistServerSettingsView(ristServer: database.ristServer)
                RtspClientSettingsView(rtspClient: database.rtspClient)
                WhepClientSettingsView(whepClient: database.whepClient)
                if #available(iOS 26, *), false {
                    NavigationLink {
                        WiFiAwareSettingsView(model: model, wiFiAware: database.wiFiAware)
                    } label: {
                        Text(String("WiFi Aware"))
                    }
                }
            }
        }
        .navigationTitle("Ingests")
    }
}
