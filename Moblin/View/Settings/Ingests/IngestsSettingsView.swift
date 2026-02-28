import SwiftUI

struct IngestsSettingsView: View {
    let model: Model
    let database: Database

    var body: some View {
        Form {
            Section {
                RtmpServerSettingsView(rtmpServer: database.rtmpServer)
                SrtlaServerSettingsView(srtlaServer: database.srtlaServer)
                RistServerSettingsView(ristServer: database.ristServer)
                RtspClientSettingsView(rtspClient: database.rtspClient)
                WhipServerSettingsView(whipServer: database.whipServer)
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
        }
        .navigationTitle("Ingests")
    }
}
